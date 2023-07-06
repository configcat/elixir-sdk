defmodule ConfigCat.CachePolicy.Manual do
  @moduledoc false

  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Behaviour
  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.Constants

  require Constants
  require Logger

  defstruct mode: "m"

  @type t :: %__MODULE__{mode: String.t()}

  @behaviour Behaviour

  @spec new :: t()
  def new do
    %__MODULE__{}
  end

  @spec start_link(CachePolicy.options()) :: GenServer.on_start()
  def start_link(options) do
    Helpers.start_link(__MODULE__, options)
  end

  defp via_tuple(instance_id) do
    Helpers.via_tuple(__MODULE__, instance_id)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl Behaviour
  def get(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:get)
  end

  @impl Behaviour
  def is_offline(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:is_offline, Constants.fetch_timeout())
  end

  @impl Behaviour
  def set_offline(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:set_offline, Constants.fetch_timeout())
  end

  @impl Behaviour
  def set_online(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:set_online, Constants.fetch_timeout())
  end

  @impl Behaviour
  def force_refresh(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:force_refresh, Constants.fetch_timeout())
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
    {:reply, :ok, Map.put(state, :offline, false)}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    if state.offline do
      Logger.warn("Client is in offline mode; it cannot initiate HTTP calls.")
      {:reply, :ok, state}
    else
      case Helpers.refresh_config(state) do
        :ok ->
          {:reply, :ok, state}

        error ->
          {:reply, error, state}
      end
    end
  end
end
