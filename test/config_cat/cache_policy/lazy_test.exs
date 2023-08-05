defmodule ConfigCat.CachePolicy.LazyTest do
  use ConfigCat.CachePolicyCase, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Lazy
  alias ConfigCat.ConfigEntry

  @policy CachePolicy.lazy(cache_expiry_seconds: 300)

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.lazy(cache_expiry_seconds: seconds)

      assert policy == %Lazy{cache_expiry_ms: seconds * 1000, mode: "l"}
    end
  end

  describe "getting the config" do
    test "fetches config when first requested", %{config: config} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(config)

      assert {:ok, ^config} = CachePolicy.get(instance_id)
    end

    test "skips initial fetch if cache is already populated with a recent entry",
         %{config: config} do
      entry = ConfigEntry.new(config, "ETag")
      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      expect_not_refreshed()
      assert {:ok, ^config} = CachePolicy.get(instance_id)
    end

    test "performs initial fetch if cache is already populated with an older entry",
         %{config: config} do
      entry =
        ConfigEntry.new(%{"old" => "config"}, "ETag")
        |> Map.update!(:fetch_time_ms, &(&1 - @policy.cache_expiry_ms - 1))

      {:ok, instance_id} = start_cache_policy(@policy, initial_entry: entry)

      expect_refresh(config)
      assert {:ok, ^config} = CachePolicy.get(instance_id)
    end

    test "doesn't re-fetch if cache has not expired", %{config: config} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(config)
      CachePolicy.force_refresh(instance_id)

      expect_not_refreshed()
      CachePolicy.get(instance_id)
    end

    test "re-fetches if cache has expired", %{config: config} do
      policy = CachePolicy.lazy(cache_expiry_seconds: 0)
      {:ok, instance_id} = start_cache_policy(policy)
      old_config = %{"old" => "config"}

      expect_refresh(old_config)
      CachePolicy.force_refresh(instance_id)

      expect_refresh(config)
      assert {:ok, ^config} = CachePolicy.get(instance_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(config)

      assert :ok = CachePolicy.force_refresh(instance_id)
      assert {:ok, ^config} = CachePolicy.get(instance_id)
    end

    test "fetches new config even if cache is not expired", %{config: config} do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_refresh(config)
      CachePolicy.force_refresh(instance_id)

      expect_refresh(config)
      CachePolicy.force_refresh(instance_id)
    end

    test "does not update config when server responds that the config hasn't changed" do
      {:ok, instance_id} = start_cache_policy(@policy)

      expect_unchanged()

      assert :ok = CachePolicy.force_refresh(instance_id)
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, instance_id} = start_cache_policy(@policy)

      assert_returns_error(fn -> CachePolicy.force_refresh(instance_id) end)
    end
  end

  describe "offline" do
    @tag capture_log: true
    test "does not fetch config when offline mode is set", %{config: config} do
      {:ok, instance_id} = start_cache_policy(@policy)
      assert CachePolicy.is_offline(instance_id) == false

      expect_refresh(config)
      assert :ok = CachePolicy.force_refresh(instance_id)

      assert :ok = CachePolicy.set_offline(instance_id)
      assert CachePolicy.is_offline(instance_id) == true

      expect_not_refreshed()
      assert :ok = CachePolicy.force_refresh(instance_id)

      assert :ok = CachePolicy.set_online(instance_id)
      assert CachePolicy.is_offline(instance_id) == false

      expect_refresh(config)
      assert :ok = CachePolicy.force_refresh(instance_id)
    end
  end
end
