defmodule ConfigCat.InMemoryCache do
  @moduledoc false

  use GenServer

  alias ConfigCat.ConfigCache

  @behaviour ConfigCache

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_options) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl ConfigCache
  def get(cache_key) do
    GenServer.call(__MODULE__, {:get, cache_key})
  end

  @impl ConfigCache
  def set(cache_key, value) do
    GenServer.call(__MODULE__, {:set, cache_key, value})
  end

  @spec clear :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{}}
  end

  @impl GenServer
  def handle_call({:get, cache_key}, _from, state) do
    result =
      case Map.get(state, cache_key) do
        nil -> {:error, :not_found}
        value -> {:ok, value}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:set, cache_key, value}, _from, state) do
    {:reply, :ok, Map.put(state, cache_key, value)}
  end
end
