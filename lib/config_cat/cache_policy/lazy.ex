defmodule ConfigCat.CachePolicy.Lazy do
  @moduledoc false

  use ConfigCat.CachePolicy.Behaviour
  use GenServer

  alias ConfigCat.CachePolicy.Helpers

  require Logger

  @enforce_keys [:cache_expiry_seconds]
  defstruct [:cache_expiry_seconds, mode: "l"]

  @type options :: keyword() | map()
  @type t :: %__MODULE__{
          cache_expiry_seconds: non_neg_integer(),
          mode: String.t()
        }

  @spec new(options()) :: t()
  def new(options) do
    struct(__MODULE__, options)
  end

  @impl GenServer
  def init(state) do
    state = Map.put(state, :last_update, nil)
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

  defp needs_fetch?(%{last_update: nil}), do: true

  defp needs_fetch?(%{cache_expiry_seconds: expiry_seconds, last_update: last_update}) do
    :gt !==
      last_update
      |> DateTime.add(expiry_seconds, :second)
      |> DateTime.compare(now())
  end

  defp refresh(state) do
    case Helpers.refresh_config(state) do
      :ok -> {:ok, %{state | last_update: now()}}
      error -> error
    end
  end

  defp now, do: DateTime.utc_now()
end
