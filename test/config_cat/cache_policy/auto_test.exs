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

    test "does not have a change callback by default" do
      policy = CachePolicy.auto()
      assert policy.on_changed == nil
    end

    test "takes an optional change callback" do
      callback = fn -> :ok end
      policy = CachePolicy.auto(on_changed: callback)
      assert policy.on_changed == callback
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
      old_config = %{"old" => "config"}

      expect_refresh(old_config)

      policy = CachePolicy.auto(poll_interval_seconds: 1)
      {:ok, policy_id} = start_cache_policy(policy)

      expect_refresh(config)
      wait_for_poll(policy)

      assert {:ok, ^config} = Auto.get(policy_id)
    end

    test "calls the change callback after refreshing", %{config: config} do
      test_pid = self()
      interval = 1
      old_config = %{"old" => "config"}

      expect_refresh(old_config)

      policy =
        CachePolicy.auto(
          on_changed: fn -> send(test_pid, :callback) end,
          poll_interval_seconds: interval
        )

      {:ok, _} = start_cache_policy(policy)

      assert_receive(:callback)

      expect_refresh(config)
      wait_for_poll(policy)

      assert_receive(:callback)
    end

    test "doesn't call the change callback if the configuration hasn't changed", %{config: config} do
      test_pid = self()
      interval = 1

      expect_refresh(config)

      policy =
        CachePolicy.auto(
          on_changed: fn -> send(test_pid, :callback) end,
          poll_interval_seconds: interval
        )

      {:ok, _} = start_cache_policy(policy)

      assert_receive(:callback)

      expect_unchanged()
      wait_for_poll(policy)

      refute_receive(:callback)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      old_config = %{"old" => "config"}
      expect_refresh(old_config)

      {:ok, policy_id} = start_cache_policy(@policy)
      assert {:ok, ^old_config} = Auto.get(policy_id)

      expect_refresh(config)
      assert :ok = Auto.force_refresh(policy_id)
      assert {:ok, ^config} = Auto.get(policy_id)
    end

    test "calls the change callback", %{config: config} do
      test_pid = self()
      old_config = %{"old" => "config"}
      expect_refresh(old_config)

      policy = CachePolicy.auto(on_changed: fn -> send(test_pid, :callback) end)
      {:ok, policy_id} = start_cache_policy(policy)

      assert_receive(:callback)

      expect_refresh(config)
      :ok = Auto.force_refresh(policy_id)

      assert_receive(:callback)
    end

    @tag capture_log: true
    test "handles errors in the change callback", %{config: config} do
      test_pid = self()
      expect_refresh(config)

      callback = fn ->
        send(test_pid, :callback)
        raise RuntimeError, "callback failed"
      end

      policy = CachePolicy.auto(on_changed: callback)
      {:ok, policy_id} = start_cache_policy(policy)

      assert {:ok, ^config} = Auto.get(policy_id)
      assert_receive(:callback)
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

  defp wait_for_poll(policy) do
    (policy.poll_interval_seconds * 1000 + 50)
    |> Process.sleep()
  end
end
