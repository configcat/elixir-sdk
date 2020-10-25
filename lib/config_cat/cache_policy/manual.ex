defmodule ConfigCat.CachePolicy.Manual do
  use GenServer

  alias ConfigCat.CachePolicy

  defstruct mode: "m"

  @behaviour CachePolicy

  def new do
    %__MODULE__{}
  end

  def start_link(options) do
    {name, options} = Keyword.pop!(options, :name)

    initial_state =
      default_options()
      |> Keyword.merge(options)
      |> Keyword.take([:cache, :cache_key, :fetcher, :fetcher_id])
      |> Enum.into(%{})

    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  defp default_options, do: [fetcher: ConfigCat.CacheControlConfigFetcher]

  @impl GenServer
  def init(state) do
    {:ok, state}
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
