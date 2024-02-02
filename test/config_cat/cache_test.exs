defmodule ConfigCat.CacheTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.Cache
  alias ConfigCat.Config
  alias ConfigCat.ConfigEntry
  alias ConfigCat.Hooks
  alias ConfigCat.MockConfigCache

  @config Config.new()
  @entry ConfigEntry.new(@config, "ETAG")
  @serialized ConfigEntry.serialize(@entry)

  describe "generating a cache key" do
    for {sdk_key, expected_cache_key} <- [
          {"configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012", "f83ba5d45bceb4bb704410f51b704fb6dfa19942"},
          {"configcat-sdk-1/TEST_KEY2-123456789012/1234567890123456789012", "da7bfd8662209c8ed3f9db96daed4f8d91ba5876"}
        ] do
      test "generates platform-independent cache keys - #{sdk_key}" do
        sdk_key = unquote(sdk_key)
        expected_cache_key = unquote(expected_cache_key)
        assert Cache.generate_key(sdk_key) == expected_cache_key
      end
    end
  end

  describe "interacting with the ConfigCache" do
    setup do
      cache_key = UUID.uuid4()
      instance_id = UUID.uuid4()
      test_pid = self()
      on_error = fn message -> send(test_pid, {:on_error, message}) end

      start_supervised!({Hooks, hooks: [on_error: on_error], instance_id: instance_id})

      cache =
        start_supervised!({Cache, cache: MockConfigCache, cache_key: cache_key, instance_id: instance_id})

      Mox.allow(MockConfigCache, self(), cache)

      %{cache_key: cache_key, instance_id: instance_id}
    end

    test "fetches from ConfigCache on first get request", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      expect(MockConfigCache, :get, fn ^cache_key -> {:ok, @serialized} end)
      refute_received {:on_error, _message}

      assert {:ok, @entry} = Cache.get(instance_id)
    end

    test "does not fetch from ConfigCache on subsequent get requests", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      expect(MockConfigCache, :get, 1, fn ^cache_key -> {:ok, @serialized} end)
      {:ok, @entry} = Cache.get(instance_id)

      assert {:ok, @entry} = Cache.get(instance_id)
    end

    test "writes to ConfigCache when caching a new entry", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      expect(MockConfigCache, :set, fn ^cache_key, @serialized -> :ok end)
      assert :ok = Cache.set(instance_id, @entry)
    end

    test "does not fetch from ConfigCache when reading after caching a new entry", %{
      cache_key: cache_key,
      instance_id: instance_id
    } do
      MockConfigCache
      |> stub(:set, fn ^cache_key, @serialized -> :ok end)
      |> expect(:get, 0, fn _cache_key -> :not_called end)

      :ok = Cache.set(instance_id, @entry)

      assert {:ok, @entry} = Cache.get(instance_id)
    end

    @tag capture_log: true
    test "calls on_error hook when cache format is invalid", %{
      instance_id: instance_id
    } do
      stub(MockConfigCache, :get, fn _cache_key -> {:ok, ""} end)
      {:error, :not_found} = Cache.get(instance_id)

      assert_received {:on_error, message}
      assert message =~ ~r/Error occurred while reading the cache. .*fewer.*/
    end
  end
end
