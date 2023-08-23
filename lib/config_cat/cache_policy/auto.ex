defmodule ConfigCat.CachePolicy.Auto do
  @moduledoc false

  use ConfigCat.CachePolicy.Behaviour
  use GenServer
  use TypedStruct

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.CachePolicy.Helpers.State
  alias ConfigCat.ConfigEntry
  alias ConfigCat.FetchTime

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @default_max_init_wait_time_seconds 5
  @default_poll_interval_seconds 60

  typedstruct enforce: true do
    field :max_init_wait_time_ms, non_neg_integer(),
      default: @default_max_init_wait_time_seconds * 1000

    field :mode, String.t(), default: "a"
    field :poll_interval_ms, pos_integer(), default: @default_poll_interval_seconds * 1000
  end

  @type on_changed_callback :: CachePolicy.on_changed_callback()
  @type options :: keyword() | map()

  @spec new(options()) :: t()
  def new(options \\ []) do
    {max_init_wait_time_seconds, options} =
      Keyword.pop(options, :max_init_wait_time_seconds, @default_max_init_wait_time_seconds)

    {poll_interval_seconds, options} =
      Keyword.pop(options, :poll_interval_seconds, @default_poll_interval_seconds)

    options =
      [
        max_init_wait_time_ms: max(max_init_wait_time_seconds, 0) * 1000,
        poll_interval_ms: max(poll_interval_seconds, 1) * 1000
      ]
      |> Keyword.merge(options)

    struct(__MODULE__, options)
  end

  @impl GenServer
  def init(%State{} = state) do
    Logger.metadata(instance_id: state.instance_id)
    {:ok, state, {:continue, :initial_fetch}}
  end

  @impl GenServer
  def handle_continue(:initial_fetch, %State{} = state) do
    unless state.offline do
      initial_refresh(state)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:polled_refresh, %State{} = state) do
    pid = self()

    unless state.offline do
      Task.start_link(fn ->
        Logger.metadata(instance_id: state.instance_id)
        refresh(state)
        schedule_next_refresh(state, pid)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get, _from, %State{} = state) do
    {:reply, Helpers.cached_settings(state), state}
  end

  @impl GenServer
  def handle_call(:is_offline, _from, %State{} = state) do
    {:reply, state.offline, state}
  end

  @impl GenServer
  def handle_call(:set_offline, _from, %State{} = state) do
    {:reply, :ok, State.set_offline(state)}
  end

  @impl GenServer
  def handle_call(:set_online, _from, %State{} = state) do
    new_state = State.set_online(state)
    initial_refresh(new_state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, %State{} = state) do
    if state.offline do
      message = "Client is in offline mode; it cannot initiate HTTP calls."
      ConfigCatLogger.warn(message)
      {:reply, {:error, message}, state}
    else
      case refresh(state) do
        :ok ->
          {:reply, :ok, state}

        error ->
          {:reply, error, state}
      end
    end
  end

  defp initial_refresh(%State{} = state) do
    interval_ms = state.policy_options.poll_interval_ms

    delay_ms =
      case Helpers.cached_entry(state) do
        {:ok, %ConfigEntry{} = entry} ->
          next_fetch_ms = entry.fetch_time_ms + interval_ms
          max(0, next_fetch_ms - FetchTime.now_ms())

        _ ->
          0
      end

    if delay_ms == 0 do
      refresh(state)
      Helpers.on_client_ready(state)
      schedule_next_refresh(state)
    else
      Helpers.on_client_ready(state)
      Process.send_after(self(), :polled_refresh, delay_ms)
    end
  end

  defp schedule_next_refresh(%State{} = state, pid \\ self()) do
    interval_ms = state.policy_options.poll_interval_ms

    Process.send_after(pid, :polled_refresh, interval_ms)
  end

  defp refresh(%State{} = state) do
    if state.offline do
      ConfigCatLogger.warn("Client is in offline mode; it cannot initiate HTTP calls.")
      :ok
    else
      Helpers.refresh_config(state)
    end
  end
end
