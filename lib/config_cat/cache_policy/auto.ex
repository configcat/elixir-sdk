defmodule ConfigCat.CachePolicy.Auto do
  @moduledoc false

  use ConfigCat.CachePolicy.Behaviour
  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Helpers

  require Logger

  defstruct mode: "a", on_changed: nil, poll_interval_seconds: 60

  @type on_changed_callback :: CachePolicy.on_changed_callback()
  @type options :: keyword() | map()
  @type t :: %__MODULE__{
          mode: String.t(),
          on_changed: on_changed_callback(),
          poll_interval_seconds: pos_integer()
        }

  @spec new(options()) :: t()
  def new(options \\ []) do
    struct(__MODULE__, options)
    |> Map.update!(:poll_interval_seconds, &max(&1, 1))
  end

  @impl GenServer
  def init(state) do
    {:ok, state, {:continue, :initial_fetch}}
  end

  @impl GenServer
  def handle_continue(:initial_fetch, state) do
    unless state.offline do
      refresh(state)
      schedule_next_refresh(state)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:polled_refresh, state) do
    pid = self()

    unless state.offline do
      Task.start_link(fn ->
        refresh(state)
        schedule_next_refresh(state, pid)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    {:reply, Helpers.cached_config(state), state}
  end

  @impl GenServer
  def handle_call(:is_offline, _from, state) do
    {:reply, state.offline, state}
  end

  @impl GenServer
  def handle_call(:set_offline, _from, state) do
    {:reply, :ok, Map.put(state, :offline, true)}
  end

  @impl GenServer
  def handle_call(:set_online, _from, state) do
    schedule_next_refresh(state)
    {:reply, :ok, Map.put(state, :offline, false)}
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

  defp schedule_next_refresh(%{poll_interval_seconds: seconds}, pid \\ self()) do
    Process.send_after(pid, :polled_refresh, seconds * 1000)
  end

  defp refresh(state) do
    if state.offline do
      Logger.warn("Client is in offline mode; it cannot initiate HTTP calls.")
      :ok
    else
      with original <- Helpers.cached_config(state),
           :ok <- Helpers.refresh_config(state) do
        if config_changed?(state, original) do
          safely_call_callback(state[:on_changed])
        end

        :ok
      end
    end
  end

  defp config_changed?(state, original) do
    Helpers.cached_config(state) != original
  end

  defp safely_call_callback(nil), do: :ok

  defp safely_call_callback(callback) do
    Task.start(fn ->
      try do
        callback.()
      rescue
        e ->
          Logger.error("on_change callback failed: #{inspect(e)}")
      end
    end)
  end
end
