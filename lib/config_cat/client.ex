defmodule ConfigCat.Client do
  @moduledoc false

  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.Config
  alias ConfigCat.Config.Setting
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.EvaluationLogger
  alias ConfigCat.FetchTime
  alias ConfigCat.Hooks
  alias ConfigCat.OverrideDataSource
  alias ConfigCat.Rollout
  alias ConfigCat.User

  require ConfigCat.Config.SettingType, as: SettingType
  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

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
    Logger.metadata(instance_id: state.instance_id)
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
  def handle_call({:get_all_value_details, user}, _from, %State{} = state) do
    result =
      state
      |> do_get_all_keys()
      |> Enum.map(&do_get_value_details(&1, nil, user, state))

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_key_and_value, variation_id}, _from, %State{} = state) do
    case cached_config(state) do
      {:ok, config, _fetch_time_ms} ->
        result =
          config
          |> Config.settings()
          |> Enum.find_value(nil, &entry_matching(&1, variation_id))

        if is_nil(result) do
          ConfigCatLogger.error(
            "Could not find the setting for the specified variation ID: '#{variation_id}'",
            event_id: 2011
          )
        end

        {:reply, result, state}

      _ ->
        ConfigCatLogger.error(
          "Config JSON is not present. Returning nil.",
          event_id: 1000
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
    ConfigCatLogger.info("Switched to ONLINE mode.", event_id: 5200)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:set_offline, _from, %State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.set_offline(instance_id)
    ConfigCatLogger.info("Switched to OFFLINE mode.", event_id: 5200)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:offline?, _from, %State{} = state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.offline?(instance_id)
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
    case cached_config(state) do
      {:ok, config, _fetch_time_ms} ->
        config |> Config.settings() |> Map.keys()

      _ ->
        ConfigCatLogger.error("Config JSON is not present. Returning empty result.",
          event_id: 1000
        )

        []
    end
  end

  defp entry_matching({key, setting}, variation_id) do
    case Setting.variation_value(setting, variation_id) do
      nil -> nil
      value -> {key, value}
    end
  end

  defp evaluate(key, user, default_value, default_variation_id, %State{} = state) do
    user = if user != nil, do: user, else: state.default_user

    %EvaluationDetails{} =
      details =
      with {:ok, config, fetch_time_ms} <- cached_config(state),
           {:ok, _settings} <- Config.fetch_settings(config),
           {:ok, logger} <- EvaluationLogger.start() do
        try do
          %EvaluationDetails{} =
            details =
            Rollout.evaluate(key, user, default_value, default_variation_id, config, logger)

          check_type_mismatch(details.value, default_value)

          fetch_time =
            case FetchTime.to_datetime(fetch_time_ms) do
              {:ok, %DateTime{} = dt} -> dt
              _ -> nil
            end

          %{details | fetch_time: fetch_time}
        after
          logger
          |> EvaluationLogger.result()
          |> ConfigCatLogger.debug(event_id: 5000)

          EvaluationLogger.stop(logger)
        end
      else
        _ ->
          message =
            "Config JSON is not present when evaluating setting '#{key}'. Returning the `default_value` parameter that you specified in your application: '#{default_value}'."

          ConfigCatLogger.error(message, event_id: 1000)

          EvaluationDetails.new(
            default_value?: true,
            error: message,
            key: key,
            user: user,
            value: default_value,
            variation_id: default_variation_id
          )
      end

    Hooks.invoke_on_flag_evaluated(state.instance_id, details)
    details
  end

  defp cached_config(%State{} = state) do
    %{cache_policy: policy, flag_overrides: flag_overrides, instance_id: instance_id} = state
    local_config = OverrideDataSource.overrides(flag_overrides)

    case OverrideDataSource.behaviour(flag_overrides) do
      :local_only ->
        {:ok, local_config, 0}

      :local_over_remote ->
        with {:ok, remote_config, fetch_time_ms} <- policy.get(instance_id) do
          {:ok, Config.merge(remote_config, local_config), fetch_time_ms}
        end

      :remote_over_local ->
        with {:ok, remote_config, fetch_time_ms} <- policy.get(instance_id) do
          merged = Config.merge(local_config, remote_config)
          {:ok, merged, fetch_time_ms}
        end
    end
  end

  defp check_type_mismatch(_value, nil), do: :ok

  defp check_type_mismatch(value, default_value) do
    value_type = SettingType.from_value(value)
    default_type = SettingType.from_value(default_value)
    number_types = [SettingType.double(), SettingType.int()]

    cond do
      value_type == default_type ->
        :ok

      value_type in number_types and default_type in number_types ->
        :ok

      true ->
        ConfigCatLogger.warning(
          "The type of a setting does not match the type of the specified default value (#{default_value}). " <>
            "Setting's type was #{value_type} but the default value's type was #{default_type}. " <>
            "Please make sure that using a default value not matching the setting's type was intended.",
          event_id: 4002
        )
    end
  end
end
