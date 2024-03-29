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

  defmodule LocalState do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :callers, [GenServer.from()], default: []
      field :initialized?, boolean(), default: false
    end

    @spec add_caller(t(), GenServer.from()) :: t()
    def add_caller(%__MODULE__{} = state, caller) do
      %{state | callers: [caller | state.callers]}
    end

    @spec be_initialized(t()) :: t()
    def be_initialized(%__MODULE__{} = state) do
      %{state | callers: [], initialized?: true}
    end
  end

  @default_max_init_wait_time_seconds 5
  @default_poll_interval_seconds 60

  typedstruct enforce: true do
    field :max_init_wait_time_ms, non_neg_integer(), default: @default_max_init_wait_time_seconds * 1000

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
      Keyword.merge(
        [
          max_init_wait_time_ms: rounded_ms(max_init_wait_time_seconds, 0),
          poll_interval_ms: rounded_ms(poll_interval_seconds, 1)
        ],
        options
      )

    struct(__MODULE__, options)
  end

  defp rounded_ms(seconds, min_value) do
    seconds
    |> max(min_value)
    |> Kernel.*(1000)
    |> round()
  end

  @impl GenServer
  def init(%State{} = state) do
    Logger.metadata(instance_id: state.instance_id)
    state = Map.put(state, :policy_state, %LocalState{})

    Process.send_after(self(), :init_timeout, state.policy_options.max_init_wait_time_ms)

    {:ok, state, {:continue, :start_polling}}
  end

  defguardp initialized?(state) when state.policy_state.initialized?

  @impl GenServer
  def handle_continue(:start_polling, %State{} = state) do
    new_state =
      if state.offline do
        be_initialized(state)
      else
        schedule_initial_refresh(state)
      end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:be_initialized, %State{} = state) do
    new_state = be_initialized(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:init_timeout, %State{} = state) do
    seconds = state.policy_options.max_init_wait_time_ms / 1000

    ConfigCatLogger.warning(
      "`max_init_wait_time_seconds` for the very first fetch reached (#{seconds}). Returning cached config.",
      event_id: 4200
    )

    new_state = be_initialized(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:polled_refresh, %State{} = state) do
    pid = self()

    unless state.offline do
      Task.start_link(fn ->
        Logger.metadata(instance_id: state.instance_id)
        refresh(state)
        schedule_next_refresh(state, pid)
        send(pid, :be_initialized)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get, from, %State{} = state) when not initialized?(state) do
    new_state = State.update_policy_state(state, &LocalState.add_caller(&1, from))
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get, _from, %State{} = state) do
    {:reply, Helpers.cached_config(state), state}
  end

  @impl GenServer
  def handle_call(:offline?, _from, %State{} = state) do
    {:reply, state.offline, state}
  end

  @impl GenServer
  def handle_call(:set_offline, _from, %State{} = state) do
    {:reply, :ok, State.set_offline(state)}
  end

  @impl GenServer
  def handle_call(:set_online, _from, %State{} = state) do
    new_state =
      state
      |> State.set_online()
      |> schedule_initial_refresh()

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, %State{} = state) do
    if state.offline do
      message = ConfigCatLogger.warn_offline()
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

  defp schedule_initial_refresh(%State{} = state) do
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
      send(self(), :polled_refresh)
      state
    else
      Process.send_after(self(), :polled_refresh, delay_ms)
      be_initialized(state)
    end
  end

  defp be_initialized(%State{} = state) when initialized?(state), do: state

  defp be_initialized(%State{} = state) do
    config = Helpers.cached_config(state)

    for caller <- state.policy_state.callers do
      GenServer.reply(caller, config)
    end

    Helpers.on_client_ready(state)

    State.update_policy_state(state, &LocalState.be_initialized/1)
  end

  defp schedule_next_refresh(%State{} = state, pid) do
    interval_ms = state.policy_options.poll_interval_ms

    Process.send_after(pid, :polled_refresh, interval_ms)
  end

  defp refresh(%State{} = state) do
    if state.offline do
      ConfigCatLogger.warn_offline()
      :ok
    else
      Helpers.refresh_config(state)
    end
  end
end
