defmodule ConfigCat.CachePolicy.Manual do
  @moduledoc false

  use GenServer

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.{Behaviour, Helpers}

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
  def force_refresh(policy_id) do
    GenServer.call(policy_id, :force_refresh)
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    {:reply, Helpers.cached_config(state), state}
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    case Helpers.refresh_config(state) do
      :ok ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end
end
