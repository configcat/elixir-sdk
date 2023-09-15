defmodule ConfigCat.CachePolicyCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import Mox

  alias ConfigCat.Cache
  alias ConfigCat.CachePolicy
  alias ConfigCat.Config
  alias ConfigCat.ConfigEntry
  alias ConfigCat.ConfigFetcher.FetchError
  alias ConfigCat.Hooks
  alias ConfigCat.InMemoryCache
  alias ConfigCat.MockFetcher
  alias HTTPoison.Response

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup do
    settings = %{"some" => "settings"}

    entry =
      settings
      |> Config.new_with_settings()
      |> ConfigEntry.new("ETag")

    %{entry: entry, settings: settings}
  end

  @spec make_old_entry :: %{entry: ConfigEntry.t(), settings: Config.settings()}
  @spec make_old_entry(non_neg_integer()) :: %{
          entry: ConfigEntry.t(),
          settings: Config.settings()
        }
  def make_old_entry(age_ms \\ 0) do
    settings = %{"old" => "settings"}

    entry =
      settings
      |> Config.new_with_settings()
      |> ConfigEntry.new("OldETag")
      |> Map.update!(:fetch_time_ms, &(&1 - age_ms))

    %{entry: entry, settings: settings}
  end

  @spec start_cache_policy(CachePolicy.t(), keyword()) :: {:ok, atom()}
  def start_cache_policy(policy, options \\ []) do
    instance_id =
      Keyword.get_lazy(options, :instance_id, fn -> UUID.uuid4() |> String.to_atom() end)

    if Keyword.get(options, :start_hooks?, true) do
      start_supervised!({Hooks, instance_id: instance_id})
    end

    {:ok, cache_key} = start_cache(instance_id)

    if entry = options[:initial_entry] do
      # Bypass Cache to force it to refresh itself on first call.
      InMemoryCache.set(cache_key, ConfigEntry.serialize(entry))
    end

    {:ok, pid} =
      start_supervised(
        {CachePolicy,
         [
           cache: InMemoryCache,
           cache_key: cache_key,
           cache_policy: policy,
           fetcher: MockFetcher,
           instance_id: instance_id,
           offline: false
         ]}
      )

    allow(MockFetcher, self(), pid)

    {:ok, instance_id}
  end

  defp start_cache(instance_id) do
    cache_key = UUID.uuid4()
    InMemoryCache.clear()

    {:ok, _pid} =
      start_supervised(
        {Cache, cache: InMemoryCache, cache_key: cache_key, instance_id: instance_id}
      )

    {:ok, cache_key}
  end

  @spec expect_refresh(ConfigEntry.t()) :: Mox.t()
  def expect_refresh(entry) do
    MockFetcher
    |> expect(:fetch, fn _id, _etag ->
      {:ok, entry}
    end)
  end

  @spec expect_unchanged :: Mox.t()
  def expect_unchanged do
    MockFetcher
    |> expect(:fetch, fn _id, _etag -> {:ok, :unchanged} end)
  end

  @spec expect_not_refreshed :: Mox.t()
  def expect_not_refreshed do
    MockFetcher
    |> expect(:fetch, 0, fn _id, _etag -> :not_called end)
  end

  @spec assert_returns_error(function()) :: true
  def assert_returns_error(force_refresh_fn) do
    response = %Response{status_code: 503}
    error = FetchError.exception(reason: response, transient?: true)

    MockFetcher
    |> stub(:fetch, fn _id, _etag -> {:error, error} end)

    assert {:error, _message} = force_refresh_fn.()
  end
end
