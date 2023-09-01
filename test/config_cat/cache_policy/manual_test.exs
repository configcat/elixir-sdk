defmodule ConfigCat.CachePolicy.ManualTest do
  use ConfigCat.CachePolicyCase, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Manual
  alias ConfigCat.FetchTime

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
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_not_refreshed()

      assert {:error, :not_found} = CachePolicy.get(instance_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{entry: entry, settings: settings} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(entry)

      assert :ok = CachePolicy.force_refresh(instance_id)
      assert {:ok, settings, entry.fetch_time_ms} == CachePolicy.get(instance_id)
    end

    test "updates fetch time when server responds that the config hasn't changed", %{
      entry: entry,
      settings: settings
    } do
      entry = Map.update!(entry, :fetch_time_ms, &(&1 - 200))
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      expect_unchanged()

      before = FetchTime.now_ms()

      assert :ok = CachePolicy.force_refresh(instance_id)

      assert {:ok, ^settings, new_fetch_time_ms} = CachePolicy.get(instance_id)
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
