defmodule ConfigCat.CachePolicy.Auto do
  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.{Behaviour, Helpers}

  require Logger

  defstruct mode: "a", on_changed: nil, poll_interval_seconds: 60

  @type callback :: (() -> :ok)
  @type options :: keyword() | map()
  @type t :: %__MODULE__{
          mode: String.t(),
          on_changed: callback(),
          poll_interval_seconds: pos_integer()
        }

  @behaviour Behaviour

  @spec new(options()) :: t()
  def new(options \\ []) do
    struct(__MODULE__, options)
    |> Map.update!(:poll_interval_seconds, &max(&1, 1))
  end

  @spec start_link(CachePolicy.options()) :: GenServer.on_start()
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

  @impl Behaviour
  def get(policy_id) do
    GenServer.call(policy_id, :get)
  end

  @impl Behaviour
  def force_refresh(policy_id) do
    GenServer.call(policy_id, :force_refresh)
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    {:reply, Helpers.cached_config(state), state}
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

  defp polled_refresh(%{poll_interval_seconds: seconds} = state) do
    refresh(state)
    Process.send_after(self(), :polled_refresh, seconds * 1000)

    {:noreply, state}
  end

  defp refresh(state) do
    with original <- Helpers.cached_config(state),
         :ok <- Helpers.refresh_config(state) do
      if config_changed?(state, original) do
        safely_call_callback(state[:on_changed])
      end

      :ok
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
