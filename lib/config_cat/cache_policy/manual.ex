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
      |> Keyword.take([:cache_api, :cache_key])
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
  def force_refresh(_policy_id) do
    {:error, :not_implemented}
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    cache_api = Map.fetch!(state, :cache_api)
    cache_key = Map.fetch!(state, :cache_key)

    {:reply, cache_api.get(cache_key), state}
  end
end
