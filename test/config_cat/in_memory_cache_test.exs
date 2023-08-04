defmodule ConfigCat.InMemoryCacheTest do
  use ExUnit.Case, async: true

  alias ConfigCat.InMemoryCache, as: Cache

  @cache_key "CACHE_KEY"

  setup do
    {:ok, _pid} = start_supervised({Cache, [cache_key: @cache_key]})

    :ok
  end

  test "cache is initially empty" do
    assert Cache.get(@cache_key) == {:error, :not_found}
  end

  test "returns cached value" do
    entry = "serialized-cache-entry"

    :ok = Cache.set(@cache_key, entry)

    assert {:ok, ^entry} = Cache.get(@cache_key)
  end
end
