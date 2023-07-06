defmodule ConfigCat.CachePolicy.Helpers do
  @moduledoc false

  alias ConfigCat.CachePolicy
  alias ConfigCat.ConfigCache

  @type state :: %{
          :cache => module(),
          :cache_key => ConfigCache.key(),
          :fetcher => module(),
          :instance_id => ConfigCat.instance_id(),
          :offline => false,
          optional(atom()) => any()
        }

  @spec start_link(module(), CachePolicy.options()) :: GenServer.on_start()
  def start_link(module, options) do
    instance_id = Keyword.fetch!(options, :instance_id)
    initial_state = make_initial_state(options)

    GenServer.start_link(module, initial_state, name: via_tuple(module, instance_id))
  end

  @spec via_tuple(module(), ConfigCat.instance_id()) :: {:via, module(), term()}
  def via_tuple(module, instance_id) do
    {:via, Registry, {ConfigCat.Registry, {module, instance_id}}}
  end

  defp make_initial_state(options) do
    policy_options =
      options
      |> Keyword.fetch!(:cache_policy)
      |> Map.from_struct()
      |> Map.drop([:mode])

    default_options()
    |> Keyword.merge(options)
    |> Keyword.take([:cache, :cache_key, :fetcher, :instance_id, :offline])
    |> Map.new()
    |> Map.merge(policy_options)
  end

  defp default_options, do: [fetcher: ConfigCat.CacheControlConfigFetcher]

  @spec cached_config(state()) :: ConfigCache.result()
  def cached_config(state) do
    cache = Map.fetch!(state, :cache)
    cache_key = Map.fetch!(state, :cache_key)

    cache.get(cache_key)
  end

  @spec refresh_config(state()) :: CachePolicy.refresh_result()
  def refresh_config(state) do
    fetcher = Map.fetch!(state, :fetcher)

    case fetcher.fetch(state.instance_id) do
      {:ok, :unchanged} ->
        :ok

      {:ok, config} ->
        update_cache(state, config)
        :ok

      error ->
        error
    end
  end

  defp update_cache(state, config) do
    cache = Map.fetch!(state, :cache)
    cache_key = Map.fetch!(state, :cache_key)
    cache.set(cache_key, config)
  end
end
