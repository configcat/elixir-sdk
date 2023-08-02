defmodule ConfigCat.InMemoryCacheTest do
  use ExUnit.Case, async: true

  alias ConfigCat.InMemoryCache, as: Cache

  @cache_key "CACHE_KEY"

  setup do
    Cache.clear()

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

  test "cache is empty after clearing" do
    entry = "serialized-cache-entry"

    :ok = Cache.set(@cache_key, entry)

    assert :ok = Cache.clear()
    assert Cache.get(@cache_key) == {:error, :not_found}
  end
end
