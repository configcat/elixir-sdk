defmodule ConfigCat.InMemoryCacheTest do
  use ExUnit.Case, async: true

  alias ConfigCat.InMemoryCache

  @cache_key "CACHE_KEY"

  setup do
    InMemoryCache.clear(@cache_key)

    :ok
  end

  test "cache is initially empty" do
    assert InMemoryCache.get(@cache_key) == {:error, :not_found}
  end

  test "returns cached value" do
    entry = "serialized-cache-entry"

    :ok = InMemoryCache.set(@cache_key, entry)

    assert {:ok, ^entry} = InMemoryCache.get(@cache_key)
  end

  test "cache is empty after clearing" do
    entry = "serialized-cache-entry"

    :ok = InMemoryCache.set(@cache_key, entry)

    assert :ok = InMemoryCache.clear(@cache_key)
    assert InMemoryCache.get(@cache_key) == {:error, :not_found}
  end
end
