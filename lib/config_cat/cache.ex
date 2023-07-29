defmodule ConfigCat.Cache do
  @moduledoc false

  use GenServer

  alias ConfigCat.ConfigCache
  alias ConfigCat.ConfigEntry

  require ConfigCat.Constants, as: Constants

  defmodule State do
    @moduledoc false

    defstruct [:cache, :cache_key, :latest_entry]

    @type t :: %__MODULE__{
            cache: module(),
            cache_key: ConfigCache.key(),
            latest_entry: ConfigEntry.t() | nil
          }

    @spec new(Keyword.t()) :: t()
    def new(options) do
      struct!(__MODULE__, options)
    end

    @spec with_entry(t(), ConfigEntry.t()) :: t()
    def with_entry(%__MODULE__{} = state, %ConfigEntry{} = entry) do
      %{state | latest_entry: entry}
    end
  end

  @type option ::
          {:cache, module()}
          | {:cache_key, ConfigCache.key()}
          | {:instance_id, ConfigCat.instance_id()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(options) do
    {instance_id, options} = Keyword.pop!(options, :instance_id)

    GenServer.start_link(__MODULE__, State.new(options), name: via_tuple(instance_id))
  end

  defp via_tuple(instance_id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}}}
  end

  @spec generate_key(String.t()) :: String.t()
  def generate_key(sdk_key) do
    key = "#{sdk_key}_#{Constants.config_filename()}_#{Constants.serialization_format_version()}"

    :crypto.hash(:sha, key)
    |> Base.encode16(case: :lower)
  end

  @spec get(ConfigCat.instance_id()) ::
          {:ok, ConfigEntry.t()} | {:error, :not_found}
  def get(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:get)
  end

  @spec set(ConfigCat.instance_id(), ConfigEntry.t()) :: :ok
  def set(instance_id, %ConfigEntry{} = entry) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:set, entry})
  end

  @impl GenServer
  def init(%State{} = state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get, _from, %State{} = state) do
    if state.latest_entry do
      {:reply, {:ok, state.latest_entry}, state}
    else
      case state.cache.get(state.cache_key) do
        {:ok, config} ->
          entry = ConfigEntry.new(config, "temp-etag")
          {:reply, {:ok, entry}, State.with_entry(state, entry)}

        error ->
          {:reply, error, state}
      end
    end
  end

  @impl GenServer
  def handle_call({:set, %ConfigEntry{} = entry}, _from, %State{} = state) do
    {:reply, state.cache.set(state.cache_key, entry.config), State.with_entry(state, entry)}
  end
end
