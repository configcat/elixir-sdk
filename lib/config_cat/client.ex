defmodule ConfigCat.Client do
  @moduledoc false

  use GenServer

  alias ConfigCat.{CachePolicy, Config, Constants, Rollout, User}

  require Constants
  require Logger

  @type client :: ConfigCat.instance_id()
  @type option ::
          {:cache_policy, module()} | {:cache_policy_id, CachePolicy.id()} | {:name, client()}
  @type options :: [option]
  @type refresh_result :: CachePolicy.refresh_result()

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    with {name, options} <- Keyword.pop!(options, :name) do
      GenServer.start_link(__MODULE__, Map.new(options), name: name)
    end
  end

  @spec get_all_keys(client()) :: [Config.key()]
  def get_all_keys(client) do
    GenServer.call(client, :get_all_keys, Constants.fetch_timeout())
  end

  @spec get_value(client(), Config.key(), Config.value(), User.t() | nil) :: Config.value()
  def get_value(client, key, default_value, user \\ nil) do
    GenServer.call(client, {:get_value, key, default_value, user}, Constants.fetch_timeout())
  end

  @spec get_variation_id(client(), Config.key(), Config.variation_id(), User.t() | nil) ::
          Config.variation_id()
  def get_variation_id(client, key, default_variation_id, user \\ nil) do
    GenServer.call(
      client,
      {:get_variation_id, key, default_variation_id, user},
      Constants.fetch_timeout()
    )
  end

  @spec get_all_variation_ids(client(), User.t() | nil) :: [Config.variation_id()]
  def get_all_variation_ids(client, user \\ nil) do
    GenServer.call(client, {:get_all_variation_ids, user}, Constants.fetch_timeout())
  end

  @spec get_key_and_value(client(), Config.variation_id()) :: {Config.key(), Config.value()} | nil
  def get_key_and_value(client, variation_id) do
    GenServer.call(client, {:get_key_and_value, variation_id}, Constants.fetch_timeout())
  end

  @spec get_all_values(client(), User.t() | nil) :: %{Config.key() => Config.value()}
  def get_all_values(client, user \\ nil) do
    GenServer.call(client, {:get_all_values, user}, Constants.fetch_timeout())
  end

  @spec force_refresh(client()) :: refresh_result()
  def force_refresh(client) do
    GenServer.call(client, :force_refresh, Constants.fetch_timeout())
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
      |> Enum.reject(&is_nil/1)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    %{cache_policy: policy, cache_policy_id: policy_id} = state

    result = policy.force_refresh(policy_id)
    {:reply, result, state}
  end

  defp do_get_value(key, default_value, user, state) do
    with {:ok, result} <- evaluate(key, user, default_value, nil, state),
         {value, _variation} = result do
      value
    else
      error -> error
    end
  end

  defp do_get_all_keys(state) do
    with {:ok, config} <- cached_config(state) do
      feature_flags = Map.get(config, Constants.feature_flags(), %{})
      Map.keys(feature_flags)
    else
      {:error, :not_found} -> []
      error -> error
    end
  end

  defp do_get_variation_id(key, default_variation_id, user, state) do
    with {:ok, result} <- evaluate(key, user, nil, default_variation_id, state),
         {_value, variation} = result do
      variation
    end
  end

  defp entry_matching({key, setting}, variation_id) do
    value_matching(key, setting, variation_id) ||
      value_matching(key, Map.get(setting, Constants.rollout_rules()), variation_id) ||
      value_matching(key, Map.get(setting, Constants.percentage_rules()), variation_id)
  end

  def value_matching(key, value, variation_id) when is_list(value) do
    Enum.find_value(value, nil, &value_matching(key, &1, variation_id))
  end

  def value_matching(key, value, variation_id) do
    if Map.get(value, Constants.variation_id(), nil) == variation_id do
      {key, Map.get(value, Constants.value())}
    else
      nil
    end
  end

  defp cached_config(state) do
    %{cache_policy: policy, cache_policy_id: policy_id} = state

    policy.get(policy_id)
  end

  defp evaluate(key, user, default_value, default_variation_id, state) do
    with {:ok, config} <- cached_config(state) do
      {:ok, Rollout.evaluate(key, user, default_value, default_variation_id, config)}
    else
      {:error, :not_found} -> {:ok, {default_value, default_variation_id}}
      error -> error
    end
  end
end
