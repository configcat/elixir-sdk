defmodule ConfigCat.InMemoryCacheTest do
  use ExUnit.Case, async: true

  alias ConfigCat.InMemoryCache, as: Cache

  @cache_key "CACHE_KEY"

  setup do
    {:ok, _pid} = Cache.start_link(cache_key: @cache_key)

    :ok
  end

  test "cache is initially empty" do
    assert Cache.get(@cache_key) == {:error, :not_found}
  end

  test "returns cached value" do
    config = %{"some" => "config"}

    :ok = Cache.set(@cache_key, config)

    assert {:ok, ^config} = Cache.get(@cache_key)
  end
end
