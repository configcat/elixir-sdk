defmodule ConfigCat.CachePolicy.Manual do
  @moduledoc false

  use GenServer

  alias ConfigCat.{CachePolicy, Constants}
  alias ConfigCat.CachePolicy.{Behaviour, Helpers}

  require Constants

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

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl Behaviour
  def get(policy_id) do
    GenServer.call(policy_id, :get)
  end

  @impl Behaviour
  def is_offline(policy_id) do
    GenServer.call(policy_id, :is_offline, Constants.fetch_timeout())
  end

  @impl Behaviour
  def set_offline(policy_id) do
    GenServer.call(policy_id, :set_offline, Constants.fetch_timeout())
  end

  @impl Behaviour
  def set_online(policy_id) do
    GenServer.call(policy_id, :set_online, Constants.fetch_timeout())
  end

  @impl Behaviour
  def force_refresh(policy_id) do
    GenServer.call(policy_id, :force_refresh, Constants.fetch_timeout())
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
