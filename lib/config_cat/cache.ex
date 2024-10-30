defmodule ConfigCat.Cache do
  @moduledoc false

  use GenServer

  alias ConfigCat.Config
  alias ConfigCat.ConfigCache
  alias ConfigCat.ConfigEntry
  alias ConfigCat.Hooks

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger
  require ConfigCat.Constants, as: Constants

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :cache, module()
      field :cache_key, ConfigCache.key()
      field :instance_id, ConfigCat.instance_id()
      field :latest_entry, ConfigEntry.t(), enforce: false
    end

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
    instance_id = Keyword.fetch!(options, :instance_id)

    GenServer.start_link(__MODULE__, State.new(options), name: via_tuple(instance_id))
  end

  defp via_tuple(instance_id) do
    ConfigCat.Registry.via_tuple(__MODULE__, instance_id)
  end

  @spec generate_key(String.t()) :: String.t()
  def generate_key(sdk_key) do
    key = "#{sdk_key}_#{Constants.config_filename()}_#{Constants.serialization_format_version()}"

    :sha
    |> :crypto.hash(key)
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
    Logger.metadata(instance_id: state.instance_id)
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get, _from, %State{latest_entry: nil} = state) do
    with {:ok, serialized} <- state.cache.get(state.cache_key),
         {:ok, entry} <- deserialize(serialized),
         {:ok, settings} <- Config.fetch_settings(entry.config) do
      Hooks.invoke_on_config_changed(state.instance_id, settings)
      {:reply, {:ok, entry}, State.with_entry(state, entry)}
    else
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:get, _from, %State{} = state) do
    {:reply, {:ok, state.latest_entry}, state}
  end

  @impl GenServer
  def handle_call({:set, %ConfigEntry{} = entry}, _from, %State{} = state) do
    case state.cache.set(state.cache_key, ConfigEntry.serialize(entry)) do
      :ok ->
        :ok

      {:error, error} ->
        ConfigCatLogger.error("Error occurred while writing the cache. #{inspect(error)}",
          event_id: 2201
        )

        :ok
    end

    {:reply, :ok, State.with_entry(state, entry)}
  end

  defp deserialize(str) do
    case ConfigEntry.deserialize(str) do
      {:ok, entry} ->
        {:ok, entry}

      {:error, reason} ->
        ConfigCatLogger.error("Error occurred while reading the cache. #{reason}",
          event_id: 2200
        )

        {:error, :not_found}
    end
  end
end
