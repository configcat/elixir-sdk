defmodule ConfigCat.CachePolicy.AutoTest do
  use ConfigCat.CachePolicyCase

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Auto

  @policy CachePolicy.auto()

  setup [:set_mox_global, :verify_on_exit!]

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.auto(poll_interval_seconds: seconds)

      assert policy == %Auto{poll_interval_seconds: seconds, mode: "a"}
    end

    test "provides a default poll interval" do
      policy = CachePolicy.auto()
      assert policy.poll_interval_seconds == 60
    end

    test "enforces a minimum poll interval" do
      policy = CachePolicy.auto(poll_interval_seconds: -1)
      assert policy.poll_interval_seconds == 1
    end
  end

  describe "getting the config" do
    test "refreshes automatically after initializing", %{config: config} do
      expect_refresh(config)

      {:ok, policy_id} = start_cache_policy(@policy)

      assert {:ok, ^config} = Auto.get(policy_id)
    end

    test "doesn't refresh between poll intervals", %{config: config} do
      expect_refresh(config)
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_not_refreshed()
      Auto.get(policy_id)
    end

    test "refreshes automatically after poll interval", %{config: config} do
      interval = 1
      old_config = %{"old" => "config"}

      expect_refresh(old_config)

      policy = CachePolicy.auto(poll_interval_seconds: interval)
      {:ok, policy_id} = start_cache_policy(policy)

      expect_refresh(config)

      Process.sleep(interval * 1000)

      # Ensure previous auto-poll has completed by sending a new message
      Auto.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      expect_refresh(config)

      {:ok, policy_id} = start_cache_policy(@policy)

      expect_refresh(config)

      assert :ok = Auto.force_refresh(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed", %{
      config: config
    } do
      expect_refresh(config)
      {:ok, policy_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = Auto.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses", %{config: config} do
      expect_refresh(config)
      {:ok, policy_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> Auto.force_refresh(policy_id) end)
    end
  end
end
