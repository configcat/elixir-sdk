defmodule ConfigCat.Client do
  use GenServer

  alias ConfigCat.{CachePolicy, Config, Constants, Rollout, User}

  require Constants
  require Logger

  @type client :: atom()
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
    GenServer.call(client, :get_all_keys)
  end

  @spec get_value(client(), Config.key(), Config.value(), User.t() | nil) :: Config.value()
  def get_value(client, key, default_value, user \\ nil) do
    GenServer.call(client, {:get_value, key, default_value, user})
  end

  @spec get_variation_id(client(), Config.key(), Config.variation_id(), User.t() | nil) ::
          Config.variation_id()
  def get_variation_id(client, key, default_variation_id, user \\ nil) do
    GenServer.call(client, {:get_variation_id, key, default_variation_id, user})
  end

  @spec force_refresh(client()) :: refresh_result()
  def force_refresh(client) do
    GenServer.call(client, :force_refresh)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_all_keys, _from, state) do
    with {:ok, config} <- cached_config(state) do
      feature_flags = Map.get(config, Constants.feature_flags(), %{})
      keys = Map.keys(feature_flags)
      {:reply, keys, state}
    else
      {:error, :not_found} -> {:reply, [], state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_value, key, default_value, user}, _from, state) do
    with {:ok, result} <- evaluate(key, user, default_value, nil, state),
         {value, _variation} = result do
      {:reply, value, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_variation_id, key, default_variation_id, user}, _from, state) do
    with {:ok, result} <- evaluate(key, user, nil, default_variation_id, state),
         {_value, variation} = result do
      {:reply, variation, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    %{cache_policy: policy, cache_policy_id: policy_id} = state

    result = policy.force_refresh(policy_id)
    {:reply, result, state}
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
