defmodule ConfigCat.CachePolicyCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import Mox

  alias ConfigCat.{CachePolicy, InMemoryCache, MockFetcher}
  alias HTTPoison.Response

  @fetcher_id :fetcher_id

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup do
    config = %{"some" => "config"}

    {:ok, config: config}
  end

  def start_cache_policy(policy) do
    policy_id = UUID.uuid4() |> String.to_atom()

    {:ok, cache_key} = start_cache()

    {:ok, _pid} =
      start_supervised(
        {CachePolicy,
         [
           cache: InMemoryCache,
           cache_key: cache_key,
           cache_policy: policy,
           fetcher: MockFetcher,
           fetcher_id: @fetcher_id,
           name: policy_id,
           offline: false
         ]}
      )

    allow(MockFetcher, self(), policy_id)

    {:ok, policy_id}
  end

  defp start_cache do
    cache_key = UUID.uuid4()
    {:ok, _pid} = start_supervised({InMemoryCache, [cache_key: cache_key]})

    {:ok, cache_key}
  end

  def expect_refresh(config) do
    MockFetcher
    |> expect(:fetch, fn @fetcher_id -> {:ok, config} end)
  end

  def expect_unchanged do
    MockFetcher
    |> expect(:fetch, fn @fetcher_id -> {:ok, :unchanged} end)
  end

  def expect_not_refreshed do
    MockFetcher
    |> expect(:fetch, 0, fn @fetcher_id -> {:ok, %{}} end)
  end

  def assert_returns_error(force_refresh_fn) do
    response = %Response{status_code: 503}

    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:error, response} end)

    assert {:error, ^response} = force_refresh_fn.()
  end
end
