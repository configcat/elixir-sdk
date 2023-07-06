defmodule ConfigCat.CachePolicy.Lazy do
  @moduledoc false

  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Behaviour
  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.Constants

  require Constants
  require Logger

  @enforce_keys [:cache_expiry_seconds]
  defstruct [:cache_expiry_seconds, mode: "l"]

  @type options :: keyword() | map()
  @type t :: %__MODULE__{
          cache_expiry_seconds: non_neg_integer(),
          mode: String.t()
        }

  @behaviour Behaviour

  @spec new(options()) :: t()
  def new(options) do
    struct(__MODULE__, options)
  end

  @spec start_link(CachePolicy.options()) :: GenServer.on_start()
  def start_link(options) do
    Helpers.start_link(__MODULE__, options, %{last_update: nil})
  end

  defp via_tuple(id) do
    Helpers.via_tuple(__MODULE__, id)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl Behaviour
  def get(id) do
    id
    |> via_tuple()
    |> GenServer.call(:get, Constants.fetch_timeout())
  end

  @impl Behaviour
  def is_offline(id) do
    id
    |> via_tuple()
    |> GenServer.call(:is_offline, Constants.fetch_timeout())
  end

  @impl Behaviour
  def set_offline(id) do
    id
    |> via_tuple()
    |> GenServer.call(:set_offline, Constants.fetch_timeout())
  end

  @impl Behaviour
  def set_online(id) do
    id
    |> via_tuple()
    |> GenServer.call(:set_online, Constants.fetch_timeout())
  end

  @impl Behaviour
  def force_refresh(id) do
    id
    |> via_tuple()
    |> GenServer.call(:force_refresh, Constants.fetch_timeout())
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
