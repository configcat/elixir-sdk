defmodule ConfigCat.InMemoryCache do
  use GenServer

  alias ConfigCat.ConfigCache

  @type option :: {:cache_key, ConfigCache.key()}
  @type options :: [option]

  @behaviour ConfigCache

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    name =
      options
      |> Keyword.fetch!(:cache_key)
      |> name_from_cache_key()

    GenServer.start_link(__MODULE__, :empty, name: name)
  end

  @impl ConfigCache
  def get(cache_key) do
    GenServer.call(name_from_cache_key(cache_key), :get)
  end

  @impl ConfigCache
  def set(cache_key, value) do
    GenServer.call(name_from_cache_key(cache_key), {:set, value})
  end

  defp name_from_cache_key(cache_key) do
    String.to_atom(cache_key)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get, _from, :empty = state) do
    {:reply, {:error, :not_found}, state}
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl GenServer
  def handle_call({:set, value}, _from, _state) do
    {:reply, :ok, value}
  end
end
