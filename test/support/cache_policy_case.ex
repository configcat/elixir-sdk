defmodule ConfigCat.CachePolicyCase do
  use ExUnit.CaseTemplate

  import Mox

  alias ConfigCat.{CachePolicy, MockCache, MockFetcher}
  alias HTTPoison.Response

  @cache_key "CACHE_KEY"
  @fetcher_id :fetcher_id

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup do
    config = %{"some" => "config"}

    MockCache
    |> stub(:get, fn @cache_key -> {:ok, config} end)

    {:ok, config: config}
  end

  def start_cache_policy(policy) do
    policy_id = UUID.uuid4() |> String.to_atom()

    {:ok, _pid} =
      CachePolicy.start_link(
        cache: MockCache,
        cache_key: @cache_key,
        cache_policy: policy,
        fetcher: MockFetcher,
        fetcher_id: @fetcher_id,
        name: policy_id
      )

    allow(MockCache, self(), policy_id)
    allow(MockFetcher, self(), policy_id)

    {:ok, policy_id}
  end

  def expect_refresh(config) do
    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

    MockCache
    |> expect(:set, fn @cache_key, ^config -> :ok end)
  end

  def expect_unchanged do
    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:ok, :unchanged} end)

    MockCache
    |> expect(:set, 0, fn @cache_key, _config -> :ok end)
  end

  def expect_not_refreshed do
    MockFetcher
    |> expect(:fetch, 0, fn @fetcher_id -> {:ok, %{}} end)

    MockCache
    |> expect(:set, 0, fn @cache_key, _config -> :ok end)
  end

  def assert_returns_error(force_refresh_fn) do
    response = %Response{status_code: 503}

    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:error, response} end)

    assert {:error, ^response} = force_refresh_fn.()
  end
end
