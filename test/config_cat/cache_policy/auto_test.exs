defmodule ConfigCat.CachePolicy.AutoTest do
  use ExUnit.Case

  import Mox

  alias ConfigCat.{CachePolicy, MockCache, MockFetcher}
  alias ConfigCat.CachePolicy.Auto
  alias HTTPoison.Response

  @cache_key "CACHE_KEY"
  @fetcher_id :fetcher_id

  setup [:set_mox_global, :verify_on_exit!]

  setup do
    config = %{"some" => "config"}

    MockCache
    |> stub(:get, fn @cache_key -> {:ok, config} end)

    {:ok, config: config}
  end

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
    test "fetches configuration after initializing", %{config: config} do
      expect_refresh(config)

      {:ok, policy_id} = start_fetch_policy()

      assert {:ok, config} = Auto.get(policy_id)
    end

    test "re-fetches configuration after poll interval", %{config: config} do
      interval = 1
      old_config = %{"old" => "config"}

      expect_refresh(old_config)

      {:ok, policy_id} = start_fetch_policy(poll_interval_seconds: interval)

      expect_refresh(config)

      Process.sleep(interval * 1000)

      # Ensure previous auto-poll has completed by sending a new message
      Auto.get(policy_id)
    end
  end

  describe "refreshing the config" do
    test "stores new config in the cache", %{config: config} do
      expect_refresh(config)

      {:ok, policy_id} = start_fetch_policy()

      expect_refresh(config)

      assert :ok = Auto.force_refresh(policy_id)
    end

    test "does not update config when server responds that the config hasn't changed", %{
      config: config
    } do
      expect_refresh(config)
      {:ok, policy_id} = start_fetch_policy()

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, :unchanged} end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      assert :ok = Auto.force_refresh(policy_id)
    end

    @tag capture_log: true
    test "handles error responses", %{config: config} do
      expect_refresh(config)
      {:ok, policy_id} = start_fetch_policy()

      response = %Response{status_code: 503}

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:error, response} end)

      assert {:error, ^response} = Auto.force_refresh(policy_id)
    end
  end

  defp start_fetch_policy(options \\ []) do
    policy_id = UUID.uuid4() |> String.to_atom()

    {:ok, _pid} =
      CachePolicy.start_link(
        cache_api: MockCache,
        cache_key: @cache_key,
        cache_policy: CachePolicy.auto(options),
        fetcher_api: MockFetcher,
        fetcher_id: @fetcher_id,
        name: policy_id
      )

    {:ok, policy_id}
  end

  defp expect_refresh(config) do
    MockFetcher
    |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

    MockCache
    |> expect(:set, fn @cache_key, ^config -> :ok end)
  end
end
