defmodule ConfigCat.CachePolicy.AutoTest do
  # This test uses set_mox_global, so can't be run async
  use ConfigCat.CachePolicyCase, async: false

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Auto
  alias ConfigCat.ConfigEntry

  require ConfigCat.Constants, as: Constants

  @policy CachePolicy.auto()

  setup [:set_mox_global, :verify_on_exit!]

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.auto(poll_interval_seconds: seconds)

      assert policy == %Auto{poll_interval_ms: seconds * 1000, mode: "a"}
    end

    test "provides a default poll interval" do
      policy = CachePolicy.auto()
      assert policy.poll_interval_ms == 60_000
    end

    test "enforces a minimum poll interval" do
      policy = CachePolicy.auto(poll_interval_seconds: -1)
      assert policy.poll_interval_ms == 1000
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
    test "refreshes automatically after initializing", %{config: config, settings: settings} do
      expect_refresh(config)

      {:ok, instance_id} = start_cache_policy(@policy)

      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)
    end

    test "skips initial fetch if cache is already populated with a recent entry",
         %{config: config, settings: settings} do
      entry = ConfigEntry.new(config, "ETag")

      expect_not_refreshed()
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)
    end

    test "performs initial fetch if cache is already populated with an older entry",
         %{config: config, settings: settings} do
      entry =
        ConfigEntry.new(%{"old" => "config"}, "ETag")
        |> Map.update!(:fetch_time_ms, &(&1 - @policy.poll_interval_ms - 1))

      expect_refresh(config)
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)
    end

    test "doesn't refresh between poll intervals", %{config: config} do
      expect_refresh(config)
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_not_refreshed()
      CachePolicy.get(instance_id)
    end

    test "refreshes automatically after poll interval", %{config: config, settings: settings} do
      old_config = %{"old" => "config"}

      expect_refresh(old_config)

      policy = CachePolicy.auto(poll_interval_seconds: 1)
      {:ok, instance_id} = start_cache_policy(policy)

      expect_refresh(config)
      wait_for_poll(policy)

      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)
    end

    test "calls the change callback after refreshing", %{config: config} do
      test_pid = self()
      interval = 1
      old_config = %{Constants.feature_flags() => %{"old" => "config"}}

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
    test "stores new config in the cache", %{config: config, settings: settings} do
      old_settings = %{"old" => "config"}
      old_config = %{Constants.feature_flags() => old_settings}

      expect_refresh(old_config)

      {:ok, instance_id} = start_cache_policy(@policy)
      assert {:ok, ^old_settings, _fetch_time_ms} = CachePolicy.get(instance_id)

      expect_refresh(config)
      assert :ok = CachePolicy.force_refresh(instance_id)
      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)
    end

    test "calls the change callback", %{config: config} do
      test_pid = self()
      old_config = %{"old" => "config"}
      expect_refresh(old_config)

      policy = CachePolicy.auto(on_changed: fn -> send(test_pid, :callback) end)
      {:ok, instance_id} = start_cache_policy(policy)

      assert_receive(:callback)

      expect_refresh(config)
      :ok = CachePolicy.force_refresh(instance_id)

      assert_receive(:callback)
    end

    @tag capture_log: true
    test "handles errors in the change callback", %{config: config, settings: settings} do
      test_pid = self()
      expect_refresh(config)

      callback = fn ->
        send(test_pid, :callback)
        raise RuntimeError, "callback failed"
      end

      policy = CachePolicy.auto(on_changed: callback)
      {:ok, instance_id} = start_cache_policy(policy)

      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)
      assert_receive(:callback)
    end

    test "does not update config when server responds that the config hasn't changed", %{
      config: config
    } do
      expect_refresh(config)
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = CachePolicy.force_refresh(instance_id)
    end

    @tag capture_log: true
    test "handles error responses", %{config: config} do
      expect_refresh(config)
      {:ok, instance_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> CachePolicy.force_refresh(instance_id) end)
    end
  end

  describe "offline" do
    test "does not fetch config when offline mode is set", %{config: config, settings: settings} do
      policy = CachePolicy.auto(poll_interval_seconds: 1)

      expect_refresh(config)
      {:ok, instance_id} = start_cache_policy(policy)

      refute CachePolicy.is_offline(instance_id)
      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)

      assert :ok = CachePolicy.set_offline(instance_id)
      assert CachePolicy.is_offline(instance_id)

      expect_not_refreshed()
      wait_for_poll(policy)

      assert {:ok, ^settings, _fetch_time_ms} = CachePolicy.get(instance_id)

      new_settings = %{"new" => "config"}
      new_config = %{Constants.feature_flags() => new_settings}
      expect_refresh(new_config)

      assert :ok = CachePolicy.set_online(instance_id)
      refute CachePolicy.is_offline(instance_id)

      assert {:ok, ^new_settings, _fetch_time_ms} = CachePolicy.get(instance_id)
    end
  end

  defp wait_for_poll(policy) do
    (policy.poll_interval_ms + 50)
    |> Process.sleep()
  end
end
