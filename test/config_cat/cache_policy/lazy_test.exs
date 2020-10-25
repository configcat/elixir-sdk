defmodule ConfigCat.CachePolicy.LazyTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Lazy
  alias ConfigCat.MockCache

  @cache_key "CACHE_KEY"

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.lazy(cache_expiry_seconds: seconds)

      assert policy == %Lazy{cache_expiry_seconds: seconds, mode: "l"}
    end
  end

  describe "getting the config" do
    test "returns the cached config" do
      config = %{"some" => "config"}
      policy_id = UUID.uuid4() |> String.to_atom()

      {:ok, _pid} =
        CachePolicy.start_link(
          cache_api: MockCache,
          cache_key: @cache_key,
          cache_policy: CachePolicy.lazy(cache_expiry_seconds: 60),
          name: policy_id
        )

      allow(MockCache, self(), policy_id)

      MockCache
      |> stub(:get, fn @cache_key -> {:ok, config} end)

      assert {:ok, ^config} = Lazy.get(policy_id)
    end
  end
end
