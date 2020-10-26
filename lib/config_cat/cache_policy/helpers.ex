defmodule ConfigCat.CachePolicy.Helpers do
  def start_link(module, options, additional_state \\ %{}) do
    name = Keyword.fetch!(options, :name)
    initial_state = make_initial_state(options, additional_state)

    GenServer.start_link(module, initial_state, name: name)
  end

  defp make_initial_state(options, additional_state) do
    policy_options =
      options
      |> Keyword.fetch!(:cache_policy)
      |> Map.from_struct()
      |> Map.drop([:mode])

    default_options()
    |> Keyword.merge(options)
    |> Keyword.take([:cache, :cache_key, :fetcher, :fetcher_id])
    |> Map.new()
    |> Map.merge(policy_options)
    |> Map.merge(additional_state)
  end

  defp default_options, do: [fetcher: ConfigCat.CacheControlConfigFetcher]

  def cached_config(state) do
    cache = Map.fetch!(state, :cache)
    cache_key = Map.fetch!(state, :cache_key)

    cache.get(cache_key)
  end

  def refresh_config(state) do
    fetcher = Map.fetch!(state, :fetcher)
    fetcher_id = Map.fetch!(state, :fetcher_id)

    case fetcher.fetch(fetcher_id) do
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
