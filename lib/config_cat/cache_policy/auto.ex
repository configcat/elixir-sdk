defmodule ConfigCat.CachePolicy.Auto do
  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Helpers

  defstruct poll_interval_seconds: 60, mode: "a"

  @behaviour CachePolicy

  def new(options \\ []) do
    struct(__MODULE__, options)
    |> Map.update!(:poll_interval_seconds, &max(&1, 1))
  end

  def start_link(options) do
    Helpers.start_link(__MODULE__, options)
  end

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
    {:reply, Helpers.cached_config(state), state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    case Helpers.refresh_config(state) do
      :ok ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  defp polled_refresh(%{poll_interval_seconds: seconds} = state) do
    Helpers.refresh_config(state)
    Process.send_after(self(), :polled_refresh, seconds * 1000)

    {:noreply, state}
  end
end
