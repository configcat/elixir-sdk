defmodule ConfigCat.CachePolicy.LazyTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.{CachePolicy, MockCache, MockFetcher}
  alias ConfigCat.CachePolicy.Lazy
  alias HTTPoison.Response

  @cache_key "CACHE_KEY"
  @fetcher_id :fetcher_id

  setup :verify_on_exit!

  setup do
    config = %{"some" => "config"}

    MockCache
    |> stub(:get, fn @cache_key -> {:ok, config} end)

    {:ok, config: config}
  end

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.lazy(cache_expiry_seconds: seconds)

      assert policy == %Lazy{cache_expiry_seconds: seconds, mode: "l"}
    end
  end

  describe "getting the config" do
    test "fetches config when first requested", %{config: config} do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 300)

      expect_refresh(config)

      assert {:ok, ^config} = Lazy.get(policy_id)
    end

    test "doesn't re-fetch if cache has not expired", %{config: config} do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 300)

      expect_refresh(config)

      Lazy.force_refresh(policy_id)

      MockFetcher
      |> expect(:fetch, 0, fn @fetcher_id -> {:ok, :unchanged} end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      Lazy.get(policy_id)
    end

    test "re-fetches if cache has expired", %{config: config} do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 0)
      old_config = %{"old" => "config"}

      expect_refresh(old_config)
      Lazy.force_refresh(policy_id)

      expect_refresh(config)
      assert {:ok, ^config} = Lazy.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 300)

      expect_refresh(config)

      assert :ok = Lazy.force_refresh(policy_id)
    end

    test "fetches new config even if cache is not expired", %{config: config} do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 300)

      expect_refresh(config)
      Lazy.force_refresh(policy_id)

      expect_refresh(config)
      Lazy.force_refresh(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed" do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 300)

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, :unchanged} end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      assert :ok = Lazy.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, policy_id} = start_fetch_policy(cache_expiry_seconds: 300)

      response = %Response{status_code: 503}

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:error, response} end)

      assert {:error, ^response} = Lazy.force_refresh(policy_id)
    end
  end

  defp start_fetch_policy(options) do
    policy_id = UUID.uuid4() |> String.to_atom()

    {:ok, _pid} =
      CachePolicy.start_link(
        cache_api: MockCache,
        cache_key: @cache_key,
        cache_policy: CachePolicy.lazy(options),
        fetcher_api: MockFetcher,
        fetcher_id: @fetcher_id,
        name: policy_id
      )

    allow(MockCache, self(), policy_id)
    allow(MockFetcher, self(), policy_id)

    {:ok, policy_id}
  end

  defp expect_refresh(config) do
    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

    MockCache
    |> expect(:set, fn @cache_key, ^config -> :ok end)
  end
end
