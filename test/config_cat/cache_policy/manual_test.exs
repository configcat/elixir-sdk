defmodule ConfigCat.CachePolicy.ManualTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Manual
  alias ConfigCat.MockCache

  @cache_key "CACHE_KEY"

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode" do
      policy = CachePolicy.manual()

      assert policy == %Manual{mode: "m"}
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
          cache_policy: CachePolicy.manual(),
          name: policy_id
        )

      allow(MockCache, self(), policy_id)

      MockCache
      |> stub(:get, fn @cache_key -> {:ok, config} end)

      assert {:ok, ^config} = Manual.get(policy_id)
    end
  end
end
