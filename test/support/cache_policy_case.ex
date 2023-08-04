defmodule ConfigCat.CachePolicyCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import Mox

  alias ConfigCat.Cache
  alias ConfigCat.CachePolicy
  alias ConfigCat.ConfigEntry
  alias ConfigCat.InMemoryCache
  alias ConfigCat.MockFetcher
  alias HTTPoison.Response

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup do
    config = %{"some" => "config"}

    {:ok, config: config}
  end

  @spec start_cache_policy(CachePolicy.t()) :: {:ok, atom()}
  def start_cache_policy(policy) do
    instance_id = UUID.uuid4() |> String.to_atom()

    {:ok, cache_key} = start_cache(instance_id)

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

    {:ok, _pid} = start_supervised({InMemoryCache, [cache_key: cache_key]})

    {:ok, _pid} =
      start_supervised(
        {Cache, cache: InMemoryCache, cache_key: cache_key, instance_id: instance_id}
      )

    {:ok, cache_key}
  end

  @spec expect_refresh(Config.t()) :: Mox.t()
  def expect_refresh(config) do
    MockFetcher
    |> expect(:fetch, fn _id -> {:ok, ConfigEntry.new(config, "ETAG")} end)
  end

  @spec expect_unchanged :: Mox.t()
  def expect_unchanged do
    MockFetcher
    |> expect(:fetch, fn _id -> {:ok, :unchanged} end)
  end

  @spec expect_not_refreshed :: Mox.t()
  def expect_not_refreshed do
    MockFetcher
    |> expect(:fetch, 0, fn _id -> :not_called end)
  end

  @spec assert_returns_error(function()) :: true
  def assert_returns_error(force_refresh_fn) do
    response = %Response{status_code: 503}

    MockFetcher
    |> stub(:fetch, fn _id -> {:error, response} end)

    assert {:error, ^response} = force_refresh_fn.()
  end
end
