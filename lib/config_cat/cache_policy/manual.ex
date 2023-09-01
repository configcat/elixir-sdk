defmodule ConfigCat.CachePolicy.Manual do
  @moduledoc false

  use ConfigCat.CachePolicy.Behaviour
  use GenServer
  use TypedStruct

  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.CachePolicy.Helpers.State

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  typedstruct enforce: true do
    field :mode, String.t(), default: "m"
  end

  @spec new :: t()
  def new do
    %__MODULE__{}
  end

  @impl GenServer
  def init(%State{} = state) do
    Logger.metadata(instance_id: state.instance_id)
    {:ok, state, {:continue, :on_client_ready}}
  end

  @impl GenServer
  def handle_continue(:on_client_ready, %State{} = state) do
    Helpers.on_client_ready(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get, _from, %State{} = state) do
    {:reply, Helpers.cached_settings(state), state}
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
    {:reply, :ok, State.set_online(state)}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, %State{} = state) do
    if state.offline do
      message = ConfigCatLogger.warn_offline()
      {:reply, {:error, message}, state}
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
