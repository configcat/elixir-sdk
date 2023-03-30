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

      assert {:error, :not_found} = Manual.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(config)

      assert :ok = Manual.force_refresh(policy_id)
      assert {:ok, ^config} = Manual.get(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed" do
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = Manual.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, policy_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> Manual.force_refresh(policy_id) end)
    end
  end

  describe "offline" do
    test "dose not fetch config when offline mode is set", %{config: config} do
      {:ok, policy_id} = start_cache_policy(@policy)
      assert Manual.is_offline(policy_id) == false

      expect_refresh(config)
      assert :ok = Manual.force_refresh(policy_id)

      assert :ok = Manual.set_offline(policy_id)
      assert Manual.is_offline(policy_id) == true

      expect_not_refreshed()
      assert :ok = Manual.force_refresh(policy_id)

      assert :ok = Manual.set_online(policy_id)
      assert Manual.is_offline(policy_id) == false

      expect_refresh(config)
      assert :ok = Manual.force_refresh(policy_id)
    end
  end
end
