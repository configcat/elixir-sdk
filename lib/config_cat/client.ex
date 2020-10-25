defmodule ConfigCat.Client do
  use GenServer

  alias ConfigCat.{FetchPolicy, Rollout, Constants}

  require ConfigCat.Constants
  require Logger

  def start_link(options) do
    with {name, options} <- Keyword.pop!(options, :name) do
      initial_state = %{
        last_update: nil,
        options: Keyword.merge(default_options(), options)
      }

      GenServer.start_link(__MODULE__, initial_state, name: name)
    end
  end

  defp default_options, do: [fetcher_api: ConfigCat.CacheControlConfigFetcher]

  def get_all_keys(client) do
    GenServer.call(client, :get_all_keys)
  end

  def get_value(client, key, default_value, user \\ nil) do
    GenServer.call(client, {:get_value, key, default_value, user})
  end

  def get_variation_id(client, key, default_variation_id, user \\ nil) do
    GenServer.call(client, {:get_variation_id, key, default_variation_id, user})
  end

  def force_refresh(client) do
    GenServer.call(client, :force_refresh)
  end

  @impl GenServer
  def init(state) do
    {:ok, state, {:continue, :maybe_init_fetch}}
  end

  @impl GenServer
  def handle_call(:get_all_keys, _from, state) do
    with {:ok, new_state} <- maybe_refresh(state),
         {:ok, config} <- cached_config(new_state) do
      feature_flags = Map.get(config, Constants.feature_flags(), %{})
      keys = Map.keys(feature_flags)
      {:reply, keys, new_state}
    else
      {:error, :not_found} -> {:reply, [], state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_value, key, default_value, user}, _from, state) do
    with {:ok, result, new_state} <- evaluate(key, user, default_value, nil, state),
         {value, _variation} = result do
      {:reply, value, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_variation_id, key, default_variation_id, user}, _from, state) do
    with {:ok, result, new_state} <- evaluate(key, user, nil, default_variation_id, state),
         {_value, variation} = result do
      {:reply, variation, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    with {:ok, new_state} <- refresh(state) do
      {:reply, :ok, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  defp cached_config(%{options: options}) do
    cache_policy = Keyword.get(options, :cache_policy)
    cache_policy_id = Keyword.get(options, :cache_policy_id)

    cache_policy.get(cache_policy_id)
  end

  defp evaluate(key, user, default_value, default_variation_id, state) do
    with {:ok, new_state} <- maybe_refresh(state),
         {:ok, config} <- cached_config(new_state) do
      {:ok, Rollout.evaluate(key, user, default_value, default_variation_id, config), new_state}
    else
      {:error, :not_found} -> {:ok, {default_value, default_variation_id}, state}
      error -> error
    end
  end

  defp schedule_initial_fetch?(%{options: options}) do
    options
    |> Keyword.get(:fetch_policy)
    |> FetchPolicy.schedule_initial_fetch?()
  end

  defp maybe_refresh(%{options: options} = state) do
    options
    |> Keyword.get(:fetch_policy)
    |> maybe_refresh(state)
  end

  defp maybe_refresh(fetch_policy, %{last_update: last_update} = state) do
    if FetchPolicy.needs_fetch?(fetch_policy, last_update) do
      refresh(state)
    else
      {:ok, state}
    end
  end

  defp refresh(%{options: options} = state) do
    Logger.info("Fetching configuration from ConfigCat")

    api = Keyword.get(options, :fetcher_api)
    fetcher_id = Keyword.get(options, :fetcher_id)

    case api.fetch(fetcher_id) do
      {:ok, :unchanged} ->
        {:ok, %{state | last_update: now()}}

      {:ok, config} ->
        cache = Keyword.get(options, :cache_api)
        cache_key = Keyword.get(options, :cache_key)
        :ok = cache.set(cache_key, config)
        {:ok, %{state | last_update: now()}}

      error ->
        error
    end
  end

  defp now, do: DateTime.utc_now()

  defp schedule_and_refresh(%{options: options} = state) do
    options
    |> Keyword.get(:fetch_policy)
    |> FetchPolicy.schedule_next_fetch(self())

    case refresh(state) do
      {:ok, new_state} -> new_state
      _error -> state
    end
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    {:noreply, schedule_and_refresh(state)}
  end

  @impl GenServer
  def handle_continue(:maybe_init_fetch, state) do
    if schedule_initial_fetch?(state) do
      {:noreply, schedule_and_refresh(state)}
    else
      {:noreply, state}
    end
  end
end
