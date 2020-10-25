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
      options
      |> Keyword.take([:cache_api, :cache_key, :fetcher_api, :fetcher_id])
      |> Enum.into(%{})

    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

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
    cache_api = Map.fetch!(state, :cache_api)
    cache_key = Map.fetch!(state, :cache_key)

    {:reply, cache_api.get(cache_key), state}
  end

  defp refresh(state) do
    api = Map.fetch!(state, :fetcher_api)
    fetcher_id = Map.fetch!(state, :fetcher_id)

    case api.fetch(fetcher_id) do
      {:ok, :unchanged} ->
        :ok

      {:ok, config} ->
        cache = Map.fetch!(state, :cache_api)
        cache_key = Map.fetch!(state, :cache_key)
        cache.set(cache_key, config)

      error ->
        error
    end
  end
end
