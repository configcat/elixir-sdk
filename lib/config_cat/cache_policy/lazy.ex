defmodule ConfigCat.CachePolicy.Lazy do
  @moduledoc false

  use GenServer

  alias ConfigCat.{CachePolicy, Constants}
  alias ConfigCat.CachePolicy.{Behaviour, Helpers}

  require Constants

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

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl Behaviour
  def get(policy_id) do
    GenServer.call(policy_id, :get, Constants.fetch_timeout())
  end

  @impl Behaviour
  def force_refresh(policy_id) do
    GenServer.call(policy_id, :force_refresh, Constants.fetch_timeout())
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    with {:ok, new_state} <- maybe_refresh(state) do
      {:reply, Helpers.cached_config(new_state), new_state}
    end
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    case refresh(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  defp maybe_refresh(state) do
    if needs_fetch?(state) do
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
