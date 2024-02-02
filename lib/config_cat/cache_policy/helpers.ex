defmodule ConfigCat.CachePolicy.Helpers do
  @moduledoc false

  alias ConfigCat.Cache
  alias ConfigCat.CachePolicy
  alias ConfigCat.Config
  alias ConfigCat.ConfigEntry
  alias ConfigCat.ConfigFetcher.FetchError
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
      field :policy_state, map(), default: %{}
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

    @spec update_policy_state(t(), (map() -> map())) :: t()
    def update_policy_state(%__MODULE__{} = state, updater) do
      Map.update!(state, :policy_state, updater)
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

  @spec cached_config(State.t()) ::
          {:ok, Config.t(), FetchTime.t()} | {:error, :not_found}
  def cached_config(%State{} = state) do
    with {:ok, %ConfigEntry{} = entry} <- cached_entry(state) do
      {:ok, entry.config, entry.fetch_time_ms}
    end
  end

  @spec cached_entry(State.t()) :: {:ok, ConfigEntry.t()} | {:error, :not_found}
  def cached_entry(%State{} = state) do
    Cache.get(state.instance_id)
  end

  @spec refresh_config(State.t()) :: ConfigCat.refresh_result()
  def refresh_config(%State{} = state) do
    cached_entry =
      case cached_entry(state) do
        {:ok, %ConfigEntry{} = entry} -> entry
        _ -> nil
      end

    etag = cached_entry && cached_entry.etag

    case state.fetcher.fetch(state.instance_id, etag) do
      {:ok, :unchanged} ->
        refresh_cached_entry(state, cached_entry)
        :ok

      {:ok, %ConfigEntry{} = entry} ->
        update_cache(state, entry)

        with {:ok, settings} <- Config.fetch_settings(entry.config) do
          Hooks.invoke_on_config_changed(state.instance_id, settings)
        end

        :ok

      {:error, %FetchError{} = error} ->
        unless error.transient? do
          refresh_cached_entry(state, cached_entry)
        end

        {:error, Exception.message(error)}
    end
  end

  defp refresh_cached_entry(%State{} = _state, nil), do: :ok

  defp refresh_cached_entry(%State{} = state, %ConfigEntry{} = entry) do
    update_cache(state, ConfigEntry.refresh(entry))
    :ok
  end

  defp update_cache(%State{} = state, %ConfigEntry{} = entry) do
    Cache.set(state.instance_id, entry)
  end
end
