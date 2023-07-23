defmodule ConfigCat.CachePolicyTest do
  use ExUnit.Case, async: true

  alias ConfigCat.CachePolicy

  describe "generating a cache key" do
    test "generates platform-independent cache keys" do
      assert CachePolicy.generate_cache_key("test1") == "147c5b4c2b2d7c77e1605b1a4309f0ea6684a0c6"
      assert CachePolicy.generate_cache_key("test2") == "c09513b1756de9e4bc48815ec7a142b2441ed4d5"
    end
  end
end