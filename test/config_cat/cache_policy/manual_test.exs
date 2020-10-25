defmodule ConfigCat.CachePolicy.ManualTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.{CachePolicy, MockCache, MockFetcher}
  alias ConfigCat.CachePolicy.Manual
  alias HTTPoison.Response

  @cache_key "CACHE_KEY"
  @fetcher_id :fetcher_id

  setup :verify_on_exit!

  setup do
    config = %{"some" => "config"}
    policy_id = UUID.uuid4() |> String.to_atom()

    {:ok, _pid} =
      CachePolicy.start_link(
        cache: MockCache,
        cache_key: @cache_key,
        cache_policy: CachePolicy.manual(),
        fetcher: MockFetcher,
        fetcher_id: @fetcher_id,
        name: policy_id
      )

    allow(MockCache, self(), policy_id)
    allow(MockFetcher, self(), policy_id)

    MockCache
    |> stub(:get, fn @cache_key -> {:ok, config} end)

    {:ok, config: config, policy_id: policy_id}
  end

  describe "creation" do
    test "returns a struct with the expected polling mode" do
      policy = CachePolicy.manual()

      assert policy == %Manual{mode: "m"}
    end
  end

  describe "getting the config" do
    test "returns the config from the cache", %{config: config, policy_id: policy_id} do
      assert {:ok, ^config} = Manual.get(policy_id)
    end

    test "doesn't refresh when requesting config", %{config: config, policy_id: policy_id} do
      MockFetcher
      |> expect(:fetch, 0, fn @fetcher_id -> {:ok, config} end)

      Manual.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config, policy_id: policy_id} do
      expect_refresh(config)

      assert :ok = Manual.force_refresh(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed", %{
      policy_id: policy_id
    } do
      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, :unchanged} end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      assert :ok = Manual.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses", %{policy_id: policy_id} do
      response = %Response{status_code: 503}

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:error, response} end)

      assert {:error, ^response} = Manual.force_refresh(policy_id)
    end
  end

  defp expect_refresh(config) do
    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

    MockCache
    |> expect(:set, fn @cache_key, ^config -> :ok end)
  end
end
