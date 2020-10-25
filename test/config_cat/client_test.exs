defmodule ConfigCat.ClientTest do
  require ConfigCat.Constants

  use ExUnit.Case

  import Mox

  alias ConfigCat.{Client, Constants, FetchPolicy, MockCache, MockFetcher}
  alias HTTPoison.Response

  @cache_key "CACHE_KEY"
  @fetcher_id :fetcher_id

  setup [:set_mox_global, :verify_on_exit!]

  setup do
    feature = "FEATURE"
    value = "VALUE"
    variation = "VARIATION"

    config = %{
      Constants.feature_flags() => %{
        feature => %{
          Constants.variation_id() => variation,
          Constants.value() => value
        }
      }
    }

    {:ok, config: config, feature: feature, value: value, variation: variation}
  end

  describe "manually fetching the configuration" do
    test "fetches configuration when refreshing", %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

      MockCache
      |> expect(:set, fn @cache_key, ^config -> :ok end)

      :ok = Client.force_refresh(client)
    end

    test "does not update config when server responds that the config hasn't changed" do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, :unchanged} end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      :ok = Client.force_refresh(client)
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())
      response = %Response{status_code: 503}

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:error, response} end)

      assert {:error, ^response} = Client.force_refresh(client)
    end
  end

  describe "automatically fetching the configuration" do
    test "loads configuration after initializing", %{config: config} do
      test_pid = self()

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

      MockCache
      |> expect(:set, fn @cache_key, ^config ->
        send(test_pid, :cached)
        :ok
      end)

      {:ok, _} = start_client(fetch_policy: FetchPolicy.auto())

      assert_receive(:cached)
    end

    test "retains previous configuration if state cannot be refreshed" do
      test_pid = self()

      MockFetcher
      |> stub(:fetch, fn @fetcher_id ->
        send(test_pid, :fetched)
        {:error, %Response{status_code: 500}}
      end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      {:ok, _} = start_client(fetch_policy: FetchPolicy.auto())
      assert_receive(:fetched)
    end
  end

  describe "lazily fetching the configuration" do
    setup %{config: config} do
      MockCache
      |> stub(:get, fn @cache_key -> config end)

      :ok
    end

    test "loads configuration when first attempting to get a value", %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300))

      MockFetcher
      |> stub(:fetch, fn @fetcher_id ->
        {:ok, config}
      end)

      MockCache
      |> expect(:set, fn @cache_key, ^config -> :ok end)

      Client.get_all_keys(client)
    end

    test "does not reload configuration if cache has not expired", %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300))

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, config} end)

      MockCache
      |> expect(:set, fn @cache_key, _config -> :ok end)

      Client.force_refresh(client)

      MockFetcher
      |> expect(:fetch, 0, fn @fetcher_id -> {:ok, :unchanged} end)

      MockCache
      |> expect(:set, 0, fn @cache_key, _config -> :ok end)

      Client.get_all_keys(client)
    end

    test "refetches configuration if cache has expired", %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 0))

      MockFetcher
      |> stub(:fetch, fn @fetcher_id -> {:ok, %{"old" => "config"}} end)

      MockCache
      |> stub(:set, fn @cache_key, _config -> :ok end)

      Client.force_refresh(client)

      MockFetcher
      |> expect(:fetch, 1, fn @fetcher_id -> {:ok, config} end)

      MockCache
      |> expect(:set, 1, fn @cache_key, ^config -> :ok end)

      Client.get_all_keys(client)
    end
  end

  describe "when the configuration has been fetched" do
    setup %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      MockCache
      |> stub(:get, fn @cache_key -> {:ok, config} end)

      {:ok, client: client}
    end

    test "get_all_keys/1 returns all known keys", %{
      client: client,
      feature: feature
    } do
      assert Client.get_all_keys(client) == [feature]
    end

    test "get_value/4 looks up the value for a key", %{
      client: client,
      feature: feature,
      value: value
    } do
      assert Client.get_value(client, feature, "default") == value
    end

    test "get_variation_id/4 looks up the variation id for a key", %{
      client: client,
      feature: feature,
      variation: variation
    } do
      assert Client.get_variation_id(client, feature, "default") == variation
    end
  end

  describe "when the configuration has not been fetched" do
    setup _context do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      MockCache
      |> stub(:get, fn @cache_key -> {:error, :not_found} end)

      {:ok, client: client}
    end

    test "get_all_keys/1 returns an empty list of keys", %{client: client} do
      assert Client.get_all_keys(client) == []
    end

    test "get_value/4 returns default value", %{client: client} do
      assert Client.get_value(client, "any_feature", "default") == "default"
    end

    test "get_variation_id/4 returns default variation", %{client: client} do
      assert Client.get_variation_id(client, "any_feature", "default") == "default"
    end
  end

  defp start_client(options) do
    name = UUID.uuid4() |> String.to_atom()

    options =
      Keyword.merge(
        [
          cache_api: MockCache,
          cache_key: @cache_key,
          fetcher_api: MockFetcher,
          fetcher_id: @fetcher_id,
          name: name
        ],
        options
      )

    {:ok, _pid} = Client.start_link(options)

    {:ok, name}
  end
end
