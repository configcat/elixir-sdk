defmodule ConfigCat.CachePolicy.AutoTest do
  # This test uses set_mox_global, so can't be run async
  use ConfigCat.CachePolicyCase, async: false

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Auto
  alias ConfigCat.FetchTime
  alias ConfigCat.Hooks
  alias ConfigCat.MockFetcher

  @policy CachePolicy.auto()

  setup [:set_mox_global, :verify_on_exit!]

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      policy = CachePolicy.auto(max_init_wait_time_seconds: 123, poll_interval_seconds: 456)

      assert policy == %Auto{max_init_wait_time_ms: 123_000, poll_interval_ms: 456_000, mode: "a"}
    end

    test "provides a default max init wait time interval" do
      policy = CachePolicy.auto()
      assert policy.max_init_wait_time_ms == 5_000
    end

    test "provides a default poll interval" do
      policy = CachePolicy.auto()
      assert policy.poll_interval_ms == 60_000
    end

    test "enforces a minimum max init wait time interval" do
      policy = CachePolicy.auto(max_init_wait_time_seconds: -1)
      assert policy.max_init_wait_time_ms == 0
    end

    test "enforces a minimum poll interval" do
      policy = CachePolicy.auto(poll_interval_seconds: -1)
      assert policy.poll_interval_ms == 1000
    end
  end

  describe "getting the config" do
    test "refreshes automatically after initializing", %{
      config: config,
      entry: entry
    } do
      expect_refresh(entry)

      {:ok, instance_id} = start_cache_policy(@policy)

      assert {:ok, config, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "skips initial fetch if cache is already populated with a recent entry",
         %{config: config, entry: entry} do
      expect_not_refreshed()
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      assert {:ok, config, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "performs initial fetch if cache is already populated with an older entry",
         %{config: config, entry: entry} do
      %{entry: old_entry} = make_old_entry(@policy.poll_interval_ms + 1)

      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: old_entry)

      assert {:ok, config, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    @tag capture_log: true
    test "returns previously cached entry if max init wait time expires before initial fetch completes",
         %{entry: entry} do
      wait_time_ms = 100
      policy = CachePolicy.auto(max_init_wait_time_seconds: wait_time_ms / 1000.0)

      %{config: old_config, entry: old_entry} = make_old_entry()
      old_entry = Map.update!(old_entry, :fetch_time_ms, &(&1 - policy.poll_interval_ms - 1))

      expect(MockFetcher, :fetch, fn _id, _etag ->
        Process.sleep(wait_time_ms * 5)
        {:ok, entry}
      end)

      {:ok, instance_id} = start_cache_policy(policy, initial_entry: old_entry)

      before = FetchTime.now_ms()
      assert {:ok, old_config, old_entry.fetch_time_ms} == CachePolicy.get(instance_id)
      elapsed_ms = FetchTime.now_ms() - before

      assert wait_time_ms <= elapsed_ms && elapsed_ms <= wait_time_ms * 2
    end

    test "doesn't refresh between poll intervals", %{entry: entry} do
      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy)
      ensure_initialized(instance_id)

      expect_not_refreshed()
      CachePolicy.get(instance_id)
    end

    test "refreshes automatically after poll interval", %{
      config: config,
      entry: entry
    } do
      %{entry: old_entry} = make_old_entry()

      expect_refresh(old_entry)

      policy = CachePolicy.auto(poll_interval_seconds: 1)
      {:ok, instance_id} = start_cache_policy(policy)
      ensure_initialized(instance_id)

      expect_refresh(entry)
      wait_for_poll(policy)

      assert {:ok, config, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config, entry: entry} do
      %{config: old_config, entry: old_entry} = make_old_entry()

      expect_refresh(old_entry)

      {:ok, instance_id} = start_cache_policy(@policy)
      assert {:ok, old_config, old_entry.fetch_time_ms} == CachePolicy.get(instance_id)

      expect_refresh(entry)
      assert :ok = CachePolicy.force_refresh(instance_id)
      assert {:ok, config, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "updates fetch time when server responds that the config hasn't changed", %{
      config: config,
      entry: entry
    } do
      entry = Map.update!(entry, :fetch_time_ms, &(&1 - 200))

      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy)
      ensure_initialized(instance_id)

      expect_unchanged()

      before = FetchTime.now_ms()

      assert :ok = CachePolicy.force_refresh(instance_id)

      assert {:ok, ^config, new_fetch_time_ms} = CachePolicy.get(instance_id)
      assert before <= new_fetch_time_ms && new_fetch_time_ms <= FetchTime.now_ms()
    end

    @tag capture_log: true
    test "handles error responses", %{entry: entry} do
      expect_refresh(entry)
      {:ok, instance_id} = start_cache_policy(@policy)
      ensure_initialized(instance_id)

      assert_returns_error(fn -> CachePolicy.force_refresh(instance_id) end)
    end
  end

  describe "calling the config-changed callback" do
    setup do
      test_pid = self()
      instance_id = String.to_atom(UUID.uuid4())

      %{entry: old_entry, feature_flags: old_feature_flags} = make_old_entry()

      callback = fn feature_flags -> send(test_pid, {:config_changed, feature_flags}) end

      start_supervised!({Hooks, hooks: [on_config_changed: callback], instance_id: instance_id})

      policy = CachePolicy.auto(poll_interval_seconds: 1)

      expect_refresh(old_entry)

      {:ok, instance_id} =
        start_cache_policy(policy, instance_id: instance_id, start_hooks?: false)

      ensure_initialized(instance_id)

      assert_received {:config_changed, ^old_feature_flags}

      %{instance_id: instance_id, policy: policy}
    end

    test "calls the change callback after polled refresh", %{
      entry: entry,
      policy: policy,
      feature_flags: feature_flags
    } do
      expect_refresh(entry)
      wait_for_poll(policy)

      assert_receive {:config_changed, ^feature_flags}
    end

    test "doesn't call the change callback if the configuration hasn't changed", %{policy: policy} do
      expect_unchanged()
      wait_for_poll(policy)

      refute_receive {:config_changed, _feature_flags}
    end

    test "calls the change callback after forced refresh", %{
      entry: entry,
      instance_id: instance_id,
      feature_flags: feature_flags
    } do
      expect_refresh(entry)
      :ok = CachePolicy.force_refresh(instance_id)

      assert_receive {:config_changed, ^feature_flags}
    end
  end

  describe "offline" do
    test "does not fetch config when offline mode is set", %{
      config: config,
      entry: entry
    } do
      policy = CachePolicy.auto(poll_interval_seconds: 1)

      %{config: old_config, entry: old_entry} =
        make_old_entry(policy.poll_interval_ms + 1)

      expect_refresh(old_entry)
      {:ok, instance_id} = start_cache_policy(policy)

      refute CachePolicy.offline?(instance_id)
      assert {:ok, old_config, old_entry.fetch_time_ms} == CachePolicy.get(instance_id)

      assert :ok = CachePolicy.set_offline(instance_id)
      assert CachePolicy.offline?(instance_id)

      expect_not_refreshed()
      wait_for_poll(policy)

      assert {:ok, old_config, old_entry.fetch_time_ms} == CachePolicy.get(instance_id)

      expect_refresh(entry, self())

      assert :ok = CachePolicy.set_online(instance_id)
      refute CachePolicy.offline?(instance_id)

      assert_receive :fetch_complete

      assert {:ok, config, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end
  end

  defp ensure_initialized(instance_id) do
    _feature_flags = CachePolicy.get(instance_id)
  end

  defp wait_for_poll(policy) do
    Process.sleep(policy.poll_interval_ms + 50)
  end
end
