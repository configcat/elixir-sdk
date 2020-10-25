defmodule ConfigCat.CachePolicy.Auto do
  use GenServer

  alias ConfigCat.CachePolicy

  defstruct poll_interval_seconds: 60, mode: "a"

  @behaviour CachePolicy

  def new(options \\ []) do
    struct(__MODULE__, options)
    |> Map.update!(:poll_interval_seconds, &max(&1, 1))
  end

  def start_link(options) do
    {name, options} = Keyword.pop!(options, :name)

    policy_options =
      options
      |> Keyword.fetch!(:cache_policy)
      |> Map.from_struct()
      |> Map.drop([:mode])

    initial_state =
      default_options()
      |> Keyword.merge(options)
      |> Keyword.take([:cache, :cache_key, :fetcher, :fetcher_id])
      |> Enum.into(%{})
      |> Map.merge(policy_options)

    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  defp default_options, do: [fetcher: ConfigCat.CacheControlConfigFetcher]

  @impl GenServer
  def init(state) do
    {:ok, state, {:continue, :initial_fetch}}
  end

  @impl GenServer
  def handle_continue(:initial_fetch, state) do
    polled_refresh(state)
  end

  @impl GenServer
  def handle_info(:polled_refresh, state) do
    polled_refresh(state)
  end

  @impl CachePolicy
  def get(policy_id) do
    GenServer.call(policy_id, :get)
  end

  @impl CachePolicy
  def force_refresh(policy_id) do
    GenServer.call(policy_id, :force_refresh)
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    cached_config(state)
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    case refresh(state) do
      :ok ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  defp cached_config(state) do
    cache = Map.fetch!(state, :cache)
    cache_key = Map.fetch!(state, :cache_key)

    {:reply, cache.get(cache_key), state}
  end

  defp polled_refresh(%{poll_interval_seconds: seconds} = state) do
    refresh(state)
    Process.send_after(self(), :polled_refresh, seconds * 1000)

    {:noreply, state}
  end

  defp refresh(state) do
    fetcher = Map.fetch!(state, :fetcher)
    fetcher_id = Map.fetch!(state, :fetcher_id)

    case fetcher.fetch(fetcher_id) do
      {:ok, :unchanged} ->
        :ok

      {:ok, config} ->
        cache = Map.fetch!(state, :cache)
        cache_key = Map.fetch!(state, :cache_key)
        cache.set(cache_key, config)

      error ->
        error
    end
  end
end
