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
      options
      |> Keyword.take([:cache_api, :cache_key])
      |> Enum.into(%{})
      |> Map.merge(policy_options)

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
