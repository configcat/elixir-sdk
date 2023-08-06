defmodule ConfigCat.CachePolicy.Lazy do
  @moduledoc false

  use ConfigCat.CachePolicy.Behaviour
  use GenServer
  use TypedStruct

  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.CachePolicy.Helpers.State
  alias ConfigCat.ConfigEntry
  alias ConfigCat.FetchTime

  require Logger

  typedstruct enforce: true do
    field :cache_expiry_ms, non_neg_integer()
    field :mode, String.t(), default: "l"
  end

  @type options :: keyword() | map()

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
  def handle_call(:get, _from, %State{} = state) do
    with {:ok, new_state} <- maybe_refresh(state) do
      {:reply, Helpers.cached_settings(new_state), new_state}
    end
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
    {:reply, :ok, State.set_online(state)}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, %State{} = state) do
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

  defp maybe_refresh(%State{} = state) do
    if !state.offline && needs_fetch?(state) do
      refresh(state)
    else
      {:ok, state}
    end
  end

  defp needs_fetch?(%State{} = state) do
    expiry_ms = state.policy_options.cache_expiry_ms

    case Helpers.cached_entry(state) do
      {:ok, %ConfigEntry{} = entry} ->
        entry.fetch_time_ms + expiry_ms <= FetchTime.now_ms()

      _ ->
        true
    end
  end

  defp refresh(%State{} = state) do
    case Helpers.refresh_config(state) do
      :ok -> {:ok, state}
      error -> error
    end
  end
end
