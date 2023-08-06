defmodule ConfigCat.Client do
  @moduledoc false

  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.OverrideDataSource
  alias ConfigCat.Rollout
  alias ConfigCat.User

  require ConfigCat.Constants, as: Constants
  require Logger

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :cache_policy, module()
      field :default_user, User.t(), enforce: false
      field :flag_overrides, OverrideDataSource.t()
      field :instance_id, ConfigCat.instance_id()
    end

    @spec new(keyword()) :: t()
    def new(options) do
      options = Keyword.merge([cache_policy: CachePolicy], options)
      struct!(__MODULE__, options)
    end

    @spec clear_default_user(t()) :: t()
    def clear_default_user(%__MODULE__{} = state) do
      %{state | default_user: nil}
    end

    @spec with_default_user(t(), User.t()) :: t()
    def with_default_user(%__MODULE__{} = state, %User{} = user) do
      %{state | default_user: user}
    end
  end

  @type option ::
          {:cache_policy, module()}
          | {:default_user, User.t()}
          | {:flag_overrides, OverrideDataSource.t()}
          | {:instance_id, ConfigCat.instance_id()}
  @type options :: [option]
  @type refresh_result :: CachePolicy.refresh_result()

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    instance_id = Keyword.fetch!(options, :instance_id)
    GenServer.start_link(__MODULE__, State.new(options), name: via_tuple(instance_id))
  end

  @spec via_tuple(ConfigCat.instance_id()) :: {:via, module(), term()}
  def via_tuple(instance_id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}}}
  end

  @impl GenServer
  def init(%State{} = state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_all_keys, _from, %State{} = state) do
    result = do_get_all_keys(state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_value, key, default_value, user}, _from, %State{} = state) do
    result = do_get_value(key, default_value, user, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_value_details, key, default_value, user}, _from, %State{} = state) do
    result = do_get_value_details(key, default_value, user, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_variation_id, key, default_variation_id, user}, _from, %State{} = state) do
    result = do_get_variation_id(key, default_variation_id, user, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_all_variation_ids, user}, _from, %State{} = state) do
    result =
      state
      |> do_get_all_keys()
      |> Enum.map(&do_get_variation_id(&1, nil, user, state))
      |> Enum.reject(&is_nil/1)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_key_and_value, variation_id}, _from, %State{} = state) do
    with {:ok, settings} <- cached_settings(state),
         result <- Enum.find_value(settings, nil, &entry_matching(&1, variation_id)) do
      {:reply, result, state}
    else
      _ ->
        Logger.warn(
          "Evaluating get_key_and_value(#{variation_id}) failed. Cache is empty. Returning nil."
        )

        {:reply, nil, state}
    end
  end

  @impl GenServer
  def handle_call({:get_all_values, user}, _from, %State{} = state) do
    result =
      state
      |> do_get_all_keys()
      |> Map.new(fn key -> {key, do_get_value(key, nil, user, state)} end)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, %State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.force_refresh(instance_id)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:set_default_user, user}, _from, %State{} = state) do
    {:reply, :ok, State.with_default_user(state, user)}
  end

  @impl GenServer
  def handle_call(:clear_default_user, _from, %State{} = state) do
    {:reply, :ok, State.clear_default_user(state)}
  end

  @impl GenServer
  def handle_call(:set_online, _from, %State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.set_online(instance_id)
    Logger.info("Switched to ONLINE mode.")
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:set_offline, _from, %State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.set_offline(instance_id)
    Logger.info("Switched to OFFLINE mode.")
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:is_offline, _from, %State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.is_offline(instance_id)
    {:reply, result, state}
  end

  defp do_get_value(key, default_value, user, %State{} = state) do
    %EvaluationDetails{value: value} = evaluate(key, user, default_value, nil, state)
    value
  end

  defp do_get_value_details(key, default_value, user, %State{} = state) do
    evaluate(key, user, default_value, nil, state)
  end

  defp do_get_all_keys(%State{} = state) do
    case cached_settings(state) do
      {:ok, settings} ->
        Map.keys(settings)

      _ ->
        []
    end
  end

  defp do_get_variation_id(key, default_variation_id, user, %State{} = state) do
    %EvaluationDetails{variation_id: variation} =
      evaluate(key, user, nil, default_variation_id, state)

    variation
  end

  defp entry_matching({key, setting}, variation_id) do
    value_matching(key, setting, variation_id) ||
      value_matching(key, Map.get(setting, Constants.rollout_rules()), variation_id) ||
      value_matching(key, Map.get(setting, Constants.percentage_rules()), variation_id)
  end

  defp value_matching(key, value, variation_id) when is_list(value) do
    Enum.find_value(value, nil, &value_matching(key, &1, variation_id))
  end

  defp value_matching(key, value, variation_id) do
    if Map.get(value, Constants.variation_id(), nil) == variation_id do
      {key, Map.get(value, Constants.value())}
    else
      nil
    end
  end

  defp evaluate(key, user, default_value, default_variation_id, %State{} = state) do
    user = if user != nil, do: user, else: state.default_user

    case cached_settings(state) do
      {:ok, settings} ->
        Rollout.evaluate(key, user, default_value, default_variation_id, settings)

      _ ->
        message =
          "Config JSON is not present when evaluating setting '#{key}'. Returning the `default_value` parameter that you specified in your application: '#{default_value}'."

        EvaluationDetails.new(
          default_value?: true,
          error: message,
          key: key,
          value: default_value,
          variation_id: default_variation_id
        )
    end
  end

  defp cached_settings(%State{} = state) do
    local_settings = OverrideDataSource.overrides(state.flag_overrides)

    case OverrideDataSource.behaviour(state.flag_overrides) do
      :local_only ->
        {:ok, local_settings}

      :local_over_remote ->
        with {:ok, remote_settings} <- remote_settings(state) do
          {:ok, Map.merge(remote_settings, local_settings)}
        end

      :remote_over_local ->
        with {:ok, remote_settings} <- remote_settings(state) do
          {:ok, Map.merge(local_settings, remote_settings)}
        end
    end
  end

  defp remote_settings(%State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    with {:ok, config} <- policy.get(instance_id),
         {:ok, settings} <- Map.fetch(config, Constants.feature_flags()) do
      {:ok, settings}
    else
      _ -> {:error, :not_found}
    end
  end
end
