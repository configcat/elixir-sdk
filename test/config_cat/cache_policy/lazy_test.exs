defmodule ConfigCat.CachePolicy.LazyTest do
  use ConfigCat.CachePolicyCase, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Lazy
  alias ConfigCat.FetchTime

  @policy CachePolicy.lazy(cache_refresh_interval_seconds: 300)

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.lazy(cache_refresh_interval_seconds: seconds)

      assert policy == %Lazy{cache_refresh_interval_ms: seconds * 1000, mode: "l"}
    end
  end

  describe "getting the config" do
    test "fetches config when first requested", %{entry: entry, feature_flags: feature_flags} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(entry)

      assert {:ok, feature_flags, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "skips initial fetch if cache is already populated with a recent entry",
         %{entry: entry, feature_flags: feature_flags} do
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      expect_not_refreshed()
      assert {:ok, feature_flags, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "performs initial fetch if cache is already populated with an older entry",
         %{entry: entry, feature_flags: feature_flags} do
      %{entry: old_entry} = make_old_entry(@policy.cache_refresh_interval_ms + 1)

      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: old_entry)

      expect_refresh(entry)
      assert {:ok, feature_flags, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "doesn't re-fetch if cache has not expired", %{entry: entry} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(entry)
      :ok = CachePolicy.force_refresh(instance_id)

      expect_not_refreshed()
      CachePolicy.get(instance_id)
    end

    test "re-fetches if cache has expired", %{entry: entry, feature_flags: feature_flags} do
      policy = CachePolicy.lazy(cache_refresh_interval_seconds: 0)
      {:ok, instance_id} = start_cache_policy(policy)
      %{entry: old_entry} = make_old_entry()

      expect_refresh(old_entry)
      :ok = CachePolicy.force_refresh(instance_id)

      expect_refresh(entry)
      assert {:ok, feature_flags, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{entry: entry, feature_flags: feature_flags} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(entry)

      assert :ok = CachePolicy.force_refresh(instance_id)
      assert {:ok, feature_flags, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "fetches new config even if cache is not expired", %{entry: entry} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(entry)
      :ok = CachePolicy.force_refresh(instance_id)

      expect_refresh(entry)
      :ok = CachePolicy.force_refresh(instance_id)
    end

    test "updates fetch time when server responds that the config hasn't changed", %{
      entry: entry,
      feature_flags: feature_flags
    } do
      entry = Map.update!(entry, :fetch_time_ms, &(&1 - 200))
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      expect_unchanged()

      before = FetchTime.now_ms()

      assert :ok = CachePolicy.force_refresh(instance_id)

      assert {:ok, ^feature_flags, new_fetch_time_ms} = CachePolicy.get(instance_id)
      assert before <= new_fetch_time_ms && new_fetch_time_ms <= FetchTime.now_ms()
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, instance_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> CachePolicy.force_refresh(instance_id) end)
    end
  end

  describe "offline" do
    @tag capture_log: true
    test "does not fetch config when offline mode is set", %{entry: entry} do
      {:ok, instance_id} = start_cache_policy(@policy)
      assert CachePolicy.offline?(instance_id) == false

      expect_refresh(entry)
      assert :ok = CachePolicy.force_refresh(instance_id)

      assert :ok = CachePolicy.set_offline(instance_id)
      assert CachePolicy.offline?(instance_id) == true

      expect_not_refreshed()
      assert {:error, _message} = CachePolicy.force_refresh(instance_id)

      assert :ok = CachePolicy.set_online(instance_id)
      assert CachePolicy.offline?(instance_id) == false

      expect_refresh(entry)
      assert :ok = CachePolicy.force_refresh(instance_id)
    end
  end
end
