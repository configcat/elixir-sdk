defmodule ConfigCat.CachePolicy.Helpers do
  @moduledoc false

  alias ConfigCat.Cache
  alias ConfigCat.CachePolicy
  alias ConfigCat.Config
  alias ConfigCat.ConfigCache
  alias ConfigCat.ConfigEntry
  alias ConfigCat.FetchTime
  alias ConfigCat.Hooks

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :fetcher, module(), default: ConfigCat.CacheControlConfigFetcher
      field :instance_id, ConfigCat.instance_id()
      field :offline, boolean()
      field :policy_options, map(), default: %{}
    end

    @spec new(Keyword.t()) :: t()
    def new(options) do
      policy_options =
        options
        |> Keyword.fetch!(:cache_policy)
        |> Map.from_struct()
        |> Map.drop([:mode])

      options =
        options
        |> Keyword.take([:fetcher, :instance_id, :offline])
        |> Keyword.put(:policy_options, policy_options)

      struct!(__MODULE__, options)
    end

    @spec set_offline(t()) :: t()
    def set_offline(%__MODULE__{} = state) do
      %{state | offline: true}
    end

    @spec set_online(t()) :: t()
    def set_online(%__MODULE__{} = state) do
      %{state | offline: false}
    end
  end

  @spec start_link(module(), CachePolicy.options()) :: GenServer.on_start()
  def start_link(module, options) do
    instance_id = Keyword.fetch!(options, :instance_id)

    GenServer.start_link(module, State.new(options), name: CachePolicy.via_tuple(instance_id))
  end

  @spec on_client_ready(State.t()) :: :ok
  def on_client_ready(%State{} = state) do
    Hooks.invoke_on_client_ready(state.instance_id)
  end

  @spec cached_settings(State.t()) ::
          {:ok, Config.settings(), FetchTime.t()} | {:error, :not_found}
  def cached_settings(%State{} = state) do
    with {:ok, %ConfigEntry{} = entry} <- cached_entry(state),
         {:ok, settings} <- Config.fetch_settings(entry.config) do
      {:ok, settings, entry.fetch_time_ms}
    else
      :error ->
        {:error, :not_found}

      error ->
        error
    end
  end

  @spec cached_config(State.t()) :: ConfigCache.result()
  def cached_config(%State{} = state) do
    with {:ok, %ConfigEntry{} = entry} <- cached_entry(state) do
      {:ok, entry.config}
    end
  end

  @spec cached_entry(State.t()) :: {:ok, ConfigEntry.t()} | {:error, :not_found}
  def cached_entry(%State{} = state) do
    Cache.get(state.instance_id)
  end

  @spec refresh_config(State.t()) :: CachePolicy.refresh_result()
  def refresh_config(%State{} = state) do
    etag =
      case cached_entry(state) do
        {:ok, %ConfigEntry{} = entry} -> entry.etag
        _ -> nil
      end

    case state.fetcher.fetch(state.instance_id, etag) do
      {:ok, :unchanged} ->
        :ok

      {:ok, %ConfigEntry{} = entry} ->
        update_cache(state, entry)

        with {:ok, settings} <- Config.fetch_settings(entry.config) do
          Hooks.invoke_on_config_changed(state.instance_id, settings)
        end

        :ok

      error ->
        error
    end
  end

  defp update_cache(%State{} = state, %ConfigEntry{} = entry) do
    Cache.set(state.instance_id, entry)
  end
end
