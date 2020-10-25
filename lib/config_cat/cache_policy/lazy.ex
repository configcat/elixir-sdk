defmodule ConfigCat.CachePolicy.Lazy do
  use GenServer

  alias ConfigCat.CachePolicy

  @enforce_keys [:cache_expiry_seconds]
  defstruct [:cache_expiry_seconds, mode: "l"]

  @behaviour CachePolicy

  def new(options) do
    struct(__MODULE__, options)
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
      |> Keyword.take([:cache_api, :cache_key, :fetcher_api, :fetcher_id])
      |> Enum.into(%{})
      |> Map.merge(policy_options)
      |> Map.put(:last_update, nil)

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
    with {:ok, new_state} <- maybe_refresh(state) do
      cached_config(new_state)
    end
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    case refresh_and_record(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  defp cached_config(state) do
    cache_api = Map.fetch!(state, :cache_api)
    cache_key = Map.fetch!(state, :cache_key)

    {:reply, cache_api.get(cache_key), state}
  end

  defp maybe_refresh(state) do
    if needs_fetch?(state) do
      refresh_and_record(state)
    else
      {:ok, state}
    end
  end

  defp needs_fetch?(%{last_update: nil}), do: true

  defp needs_fetch?(%{cache_expiry_seconds: expiry_seconds, last_update: last_update}) do
    :gt !==
      last_update
      |> DateTime.add(expiry_seconds, :second)
      |> DateTime.compare(now())
  end

  defp refresh_and_record(state) do
    case refresh(state) do
      :ok -> {:ok, %{state | last_update: now()}}
      error -> error
    end
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
        :ok

      error ->
        error
    end
  end

  defp now, do: DateTime.utc_now()
end
