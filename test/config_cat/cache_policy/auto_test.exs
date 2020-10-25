defmodule ConfigCat.CachePolicy.AutoTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Auto
  alias ConfigCat.MockCache

  @cache_key "CACHE_KEY"

  setup :verify_on_exit!

  describe "creation" do
    test "returns a struct with the expected polling mode and options" do
      seconds = 123
      policy = CachePolicy.auto(poll_interval_seconds: seconds)

      assert policy == %Auto{poll_interval_seconds: seconds, mode: "a"}
    end

    test "provides a default poll interval" do
      policy = CachePolicy.auto()
      assert policy.poll_interval_seconds == 60
    end

    test "enforces a minimum poll interval" do
      policy = CachePolicy.auto(poll_interval_seconds: -1)
      assert policy.poll_interval_seconds == 1
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
          cache_policy: CachePolicy.auto(),
          name: policy_id
        )

      allow(MockCache, self(), policy_id)

      MockCache
      |> stub(:get, fn @cache_key -> {:ok, config} end)

      assert {:ok, ^config} = Auto.get(policy_id)
    end
  end
end
