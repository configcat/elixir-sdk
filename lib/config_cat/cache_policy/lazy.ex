defmodule ConfigCat.CachePolicy.Lazy do
  @moduledoc false

  use ConfigCat.CachePolicy.Behaviour
  use GenServer

  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.ConfigEntry

  require Logger

  @enforce_keys [:cache_expiry_ms]
  defstruct [:cache_expiry_ms, mode: "l"]

  @type options :: keyword() | map()
  @type t :: %__MODULE__{
          cache_expiry_ms: non_neg_integer(),
          mode: String.t()
        }

  @spec new(options()) :: t()
  def new(options) do
    {expiry_seconds, options} = Keyword.pop!(options, :cache_expiry_seconds)
    options = Keyword.put(options, :cache_expiry_ms, expiry_seconds * 1000)
    struct(__MODULE__, options)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    with {:ok, new_state} <- maybe_refresh(state) do
      {:reply, Helpers.cached_config(new_state), new_state}
    end
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
    {:reply, :ok, Map.put(state, :offline, false)}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    if state.offline do
      Logger.warn("Client is in offline mode; it cannot initiate HTTP calls.")
      {:reply, :ok, state}
    else
      case refresh(state) do
        {:ok, new_state} ->
          {:reply, :ok, new_state}

        error ->
          {:reply, error, state}
      end
    end
  end

  defp maybe_refresh(state) do
    if !state.offline && needs_fetch?(state) do
      refresh(state)
    else
      {:ok, state}
    end
  end

  defp needs_fetch?(%{cache_expiry_ms: expiry_ms} = state) do
    case Helpers.cached_entry(state) do
      {:ok, %ConfigEntry{} = entry} ->
        entry.fetch_time_ms + expiry_ms <= ConfigEntry.now()

      _ ->
        true
    end
  end

  defp refresh(state) do
    case Helpers.refresh_config(state) do
      :ok -> {:ok, state}
      error -> error
    end
  end
end
