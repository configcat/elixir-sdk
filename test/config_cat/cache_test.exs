defmodule ConfigCat.CacheTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.Cache
  alias ConfigCat.ConfigEntry
  alias ConfigCat.MockConfigCache

  @config %{"some" => "config"}
  @entry ConfigEntry.new(@config, "ETAG")

  describe "generating a cache key" do
    test "generates platform-independent cache keys" do
      assert Cache.generate_key("test1") == "147c5b4c2b2d7c77e1605b1a4309f0ea6684a0c6"
      assert Cache.generate_key("test2") == "c09513b1756de9e4bc48815ec7a142b2441ed4d5"
    end
  end

  describe "interacting with the ConfigCache" do
    setup do
      cache_key = UUID.uuid4()
      instance_id = UUID.uuid4()

      cache =
        start_supervised!(
          {Cache, cache: MockConfigCache, cache_key: cache_key, instance_id: instance_id}
        )

      Mox.allow(MockConfigCache, self(), cache)

      %{cache_key: cache_key, instance_id: instance_id}
    end

    test "fetches from ConfigCache on first get request", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      MockConfigCache
      |> expect(:get, fn ^cache_key -> {:ok, @config} end)

      assert {:ok,
              %ConfigEntry{
                config: @config
              }} = Cache.get(instance_id)
    end

    test "does not fetch from ConfigCache on subsequent get requests", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      MockConfigCache
      |> expect(:get, 1, fn ^cache_key -> {:ok, @config} end)

      {:ok, entry} = Cache.get(instance_id)

      assert {:ok, ^entry} = Cache.get(instance_id)
    end

    test "writes to ConfigCache when caching a new entry", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      MockConfigCache
      |> expect(:set, fn ^cache_key, @config -> :ok end)

      assert :ok = Cache.set(instance_id, @entry)
    end

    test "does not fetch from ConfigCache when reading after caching a new entry", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      MockConfigCache
      |> expect(:set, fn ^cache_key, @config -> :ok end)
      |> expect(:get, 0, fn _cache_key -> :not_called end)

      :ok = Cache.set(instance_id, @entry)

      assert {:ok, @entry} = Cache.get(instance_id)
    end
  end
end
