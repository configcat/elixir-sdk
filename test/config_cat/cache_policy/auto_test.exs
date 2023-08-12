defmodule ConfigCat.CachePolicy.AutoTest do
  # This test uses set_mox_global, so can't be run async
  use ConfigCat.CachePolicyCase, async: false

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Auto
  alias ConfigCat.Config
  alias ConfigCat.ConfigEntry

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
    test "refreshes automatically after initializing", %{entry: entry, settings: settings} do
      expect_refresh(entry)

      {:ok, instance_id} = start_cache_policy(@policy)

      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "skips initial fetch if cache is already populated with a recent entry",
         %{entry: entry, settings: settings} do
      expect_not_refreshed()
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "performs initial fetch if cache is already populated with an older entry",
         %{entry: entry, settings: settings} do
      %{entry: old_entry} = make_old_entry()
      old_entry = Map.update!(old_entry, :fetch_time_ms, &(&1 - @policy.poll_interval_ms - 1))

      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: old_entry)

      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "doesn't refresh between poll intervals", %{entry: entry} do
      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_not_refreshed()
      CachePolicy.get(instance_id)
    end

    test "refreshes automatically after poll interval", %{entry: entry, settings: settings} do
      %{entry: old_entry} = make_old_entry()

      expect_refresh(old_entry)

      policy = CachePolicy.auto(poll_interval_seconds: 1)
      {:ok, instance_id} = start_cache_policy(policy)

      expect_refresh(entry)
      wait_for_poll(policy)

      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "calls the change callback after refreshing", %{entry: entry} do
      test_pid = self()
      interval = 1
      %{entry: old_entry} = make_old_entry()

      expect_refresh(old_entry)

      policy =
        CachePolicy.auto(
          on_changed: fn -> send(test_pid, :callback) end,
          poll_interval_seconds: interval
        )

      {:ok, _} = start_cache_policy(policy)

      assert_receive(:callback)

      expect_refresh(entry)
      wait_for_poll(policy)

      assert_receive(:callback)
    end

    test "doesn't call the change callback if the configuration hasn't changed", %{entry: entry} do
      test_pid = self()
      interval = 1

      expect_refresh(entry)

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
    test "stores new config in the cache", %{entry: entry, settings: settings} do
      %{entry: old_entry, settings: old_settings} = make_old_entry()

      expect_refresh(old_entry)

      {:ok, instance_id} = start_cache_policy(@policy)
      assert {:ok, old_settings, old_entry.fetch_time_ms} == CachePolicy.get(instance_id)

      expect_refresh(entry)
      assert :ok = CachePolicy.force_refresh(instance_id)
      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "calls the change callback", %{entry: entry} do
      test_pid = self()
      %{entry: old_entry} = make_old_entry()
      expect_refresh(old_entry)

      policy = CachePolicy.auto(on_changed: fn -> send(test_pid, :callback) end)
      {:ok, instance_id} = start_cache_policy(policy)

      assert_receive(:callback)

      expect_refresh(entry)
      :ok = CachePolicy.force_refresh(instance_id)

      assert_receive(:callback)
    end

    @tag capture_log: true
    test "handles errors in the change callback", %{entry: entry, settings: settings} do
      test_pid = self()
      expect_refresh(entry)

      callback = fn ->
        send(test_pid, :callback)
        raise RuntimeError, "callback failed"
      end

      policy = CachePolicy.auto(on_changed: callback)
      {:ok, instance_id} = start_cache_policy(policy)

      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
      assert_receive(:callback)
    end

    test "does not update config when server responds that the config hasn't changed", %{
      entry: entry
    } do
      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = CachePolicy.force_refresh(instance_id)
    end

    @tag capture_log: true
    test "handles error responses", %{entry: entry} do
      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> CachePolicy.force_refresh(instance_id) end)
    end
  end

  describe "offline" do
    test "does not fetch config when offline mode is set", %{entry: entry, settings: settings} do
      policy = CachePolicy.auto(poll_interval_seconds: 1)

      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(policy)

      refute CachePolicy.is_offline(instance_id)
      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)

      assert :ok = CachePolicy.set_offline(instance_id)
      assert CachePolicy.is_offline(instance_id)

      expect_not_refreshed()
      wait_for_poll(policy)

      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)

      new_settings = %{"new" => "config"}
      new_config = Config.new_with_settings(new_settings)
      new_entry = ConfigEntry.new(new_config, "NEW_ETAG")

      expect_refresh(new_entry)

      assert :ok = CachePolicy.set_online(instance_id)
      refute CachePolicy.is_offline(instance_id)

      assert {:ok, new_settings, new_entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end
  end

  defp wait_for_poll(policy) do
    (policy.poll_interval_ms + 50)
    |> Process.sleep()
  end
end
