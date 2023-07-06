defmodule ConfigCat.Client do
  @moduledoc false

  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.Constants
  alias ConfigCat.OverrideDataSource
  alias ConfigCat.Rollout
  alias ConfigCat.User

  require Constants
  require Logger

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
    GenServer.start_link(__MODULE__, Map.new(options), name: via_tuple(instance_id))
  end

  @spec via_tuple(ConfigCat.instance_id()) :: {:via, module(), term()}
  def via_tuple(instance_id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}}}
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_all_keys, _from, state) do
    result = do_get_all_keys(state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_value, key, default_value, user}, _from, state) do
    result = do_get_value(key, default_value, user, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_variation_id, key, default_variation_id, user}, _from, state) do
    result = do_get_variation_id(key, default_variation_id, user, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_all_variation_ids, user}, _from, state) do
    result =
      state
      |> do_get_all_keys()
      |> Enum.map(&do_get_variation_id(&1, nil, user, state))
      |> Enum.reject(&is_nil/1)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_key_and_value, variation_id}, _from, state) do
    with {:ok, config} <- cached_config(state),
         {:ok, feature_flags} <- Map.fetch(config, Constants.feature_flags()),
         result <- Enum.find_value(feature_flags, nil, &entry_matching(&1, variation_id)) do
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
  def handle_call({:get_all_values, user}, _from, state) do
    result =
      state
      |> do_get_all_keys()
      |> Map.new(fn key -> {key, do_get_value(key, nil, user, state)} end)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.force_refresh(instance_id)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:set_default_user, user}, _from, state) do
    {:reply, :ok, Map.put(state, :default_user, user)}
  end

  @impl GenServer
  def handle_call(:clear_default_user, _from, state) do
    {:reply, :ok, Map.delete(state, :default_user)}
  end

  @impl GenServer
  def handle_call(:set_online, _from, state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.set_online(instance_id)
    Logger.info("Switched to ONLINE mode.")
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:set_offline, _from, state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.set_offline(instance_id)
    Logger.info("Switched to OFFLINE mode.")
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:is_offline, _from, state) do
    %{cache_policy: policy, instance_id: instance_id} = state

    result = policy.is_offline(instance_id)
    {:reply, result, state}
  end

  defp do_get_value(key, default_value, user, state) do
    with {:ok, result} <- evaluate(key, user, default_value, nil, state),
         {value, _variation} <- result do
      value
    end
  end

  defp do_get_all_keys(state) do
    with {:ok, config} <- cached_config(state),
         feature_flags <- Map.get(config, Constants.feature_flags(), %{}) do
      Map.keys(feature_flags)
    else
      {:error, :not_found} -> []
      error -> error
    end
  end

  defp do_get_variation_id(key, default_variation_id, user, state) do
    with {:ok, result} <- evaluate(key, user, nil, default_variation_id, state),
         {_value, variation} <- result do
      variation
    end
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

  defp evaluate(key, user, default_value, default_variation_id, state) do
    user = if user != nil, do: user, else: Map.get(state, :default_user)

    case cached_config(state) do
      {:ok, config} ->
        {:ok, Rollout.evaluate(key, user, default_value, default_variation_id, config)}

      {:error, :not_found} ->
        {:ok, {default_value, default_variation_id}}

      error ->
        error
    end
  end

  defp cached_config(%{
         cache_policy: policy,
         flag_overrides: override_data_source,
         instance_id: instance_id
       }) do
    with {:ok, local_settings} <- OverrideDataSource.overrides(override_data_source) do
      case OverrideDataSource.behaviour(override_data_source) do
        :local_only ->
          {:ok, local_settings}

        :local_over_remote ->
          with {:ok, remote_settings} <- policy.get(instance_id) do
            {:ok, merge_settings(remote_settings, local_settings)}
          end

        :remote_over_local ->
          with {:ok, remote_settings} <- policy.get(instance_id) do
            {:ok, merge_settings(local_settings, remote_settings)}
          end
      end
    end
  end

  defp merge_settings(%{Constants.feature_flags() => left_flags} = target, %{
         Constants.feature_flags() => right_flags
       }) do
    Map.put(target, Constants.feature_flags(), Map.merge(left_flags, right_flags))
  end

  defp merge_settings(target, _overrides), do: target
end
