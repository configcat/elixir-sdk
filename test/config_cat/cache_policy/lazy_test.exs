defmodule ConfigCat.CachePolicy.LazyTest do
  use ConfigCat.CachePolicyCase, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Lazy

  @policy CachePolicy.lazy(cache_expiry_seconds: 300)

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.lazy(cache_expiry_seconds: seconds)

      assert policy == %Lazy{cache_expiry_seconds: seconds, mode: "l"}
    end
  end

  describe "getting the config" do
    test "fetches config when first requested", %{config: config} do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(config)

      assert {:ok, ^config} = Lazy.get(policy_id)
    end

    test "doesn't re-fetch if cache has not expired", %{config: config} do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(config)
      Lazy.force_refresh(policy_id)

      expect_not_refreshed()
      Lazy.get(policy_id)
    end

    test "re-fetches if cache has expired", %{config: config} do
      policy = CachePolicy.lazy(cache_expiry_seconds: 0)
      {:ok, policy_id} = start_cache_policy(policy)
      old_config = %{"old" => "config"}

      expect_refresh(old_config)
      Lazy.force_refresh(policy_id)

      expect_refresh(config)
      assert {:ok, ^config} = Lazy.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(config)

      assert :ok = Lazy.force_refresh(policy_id)
      assert {:ok, ^config} = Lazy.get(policy_id)
    end

    test "fetches new config even if cache is not expired", %{config: config} do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(config)
      Lazy.force_refresh(policy_id)

      expect_refresh(config)
      Lazy.force_refresh(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed" do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = Lazy.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, policy_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> Lazy.force_refresh(policy_id) end)
    end
  end
end
