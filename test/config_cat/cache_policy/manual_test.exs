defmodule ConfigCat.CachePolicy.ManualTest do
  use ConfigCat.CachePolicyCase, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Manual

  @policy CachePolicy.manual()

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode" do
      policy = CachePolicy.manual()

      assert policy == %Manual{mode: "m"}
    end
  end

  describe "getting the config" do
    test "returns the config from the cache without refreshing" do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_not_refreshed()

      assert {:error, :not_found} = CachePolicy.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{entry: entry, settings: settings} do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(entry)

      assert :ok = CachePolicy.force_refresh(policy_id)
      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed" do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = CachePolicy.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, policy_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> CachePolicy.force_refresh(policy_id) end)
    end
  end

  describe "offline" do
    @tag capture_log: true
    test "does not fetch config when offline mode is set", %{entry: entry} do
      {:ok, policy_id} = start_cache_policy(@policy)
      assert CachePolicy.is_offline(policy_id) == false

      expect_refresh(entry)
      assert :ok = CachePolicy.force_refresh(policy_id)

      assert :ok = CachePolicy.set_offline(policy_id)
      assert CachePolicy.is_offline(policy_id) == true

      expect_not_refreshed()
      assert :ok = CachePolicy.force_refresh(policy_id)

      assert :ok = CachePolicy.set_online(policy_id)
      assert CachePolicy.is_offline(policy_id) == false

      expect_refresh(entry)
      assert :ok = CachePolicy.force_refresh(policy_id)
    end
  end
end
