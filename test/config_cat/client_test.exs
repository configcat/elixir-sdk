defmodule ConfigCat.ClientTest do
  require ConfigCat.Constants

  use ExUnit.Case

  import Mox

  alias ConfigCat.{Client, Constants, FetchPolicy}
  alias HTTPoison.Response

  @fetcher :fetcher_id

  setup [:set_mox_global, :verify_on_exit!]

  Mox.defmock(MockFetcher, for: ConfigCat.ConfigFetcher)

  setup do
    feature = "FEATURE"
    value = "VALUE"
    config = %{Constants.feature_flags() => %{feature => %{Constants.value() => value}}}

    {:ok, config: config, feature: feature, value: value}
  end

  describe "manually fetching the configuration" do
    test "fetches configuration when refreshing", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      MockFetcher
      |> stub(:fetch, fn @fetcher -> {:ok, config} end)

      :ok = Client.force_refresh(client)
      assert Client.get_value(client, feature, "default") == value
    end

    test "retains previous config when server responds that the config hasn't changed", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} = start_client(initial_config: config, fetch_policy: FetchPolicy.manual())

      MockFetcher
      |> stub(:fetch, fn @fetcher -> {:ok, :unchanged} end)

      :ok = Client.force_refresh(client)

      assert Client.get_value(client, feature, "default") == value
    end

    @tag capture_log: true
    test "handles error responses" do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())
      response = %Response{status_code: 503}

      MockFetcher
      |> stub(:fetch, fn @fetcher -> {:error, response} end)

      assert {:error, ^response} = Client.force_refresh(client)
    end
  end

  describe "automatically fetching the configuration" do
    test "loads configuration after initializing", %{
      config: config,
      feature: feature,
      value: value
    } do
      MockFetcher
      |> stub(:fetch, fn @fetcher ->
        {:ok, config}
      end)

      {:ok, client} = start_client(fetch_policy: FetchPolicy.auto())

      assert Client.get_value(client, feature, "default") == value
    end

    test "retains previous configuration if state cannot be refreshed", %{
      feature: feature,
      config: config,
      value: value
    } do
      MockFetcher
      |> stub(:fetch, fn @fetcher ->
        {:error, %Response{status_code: 500}}
      end)

      {:ok, client} = start_client(fetch_policy: FetchPolicy.auto(), initial_config: config)

      assert Client.get_value(client, feature, "default") == value
    end
  end

  describe "lazily fetching the configuration" do
    test "loads configuration when first attempting to get a value", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300))

      MockFetcher
      |> stub(:fetch, fn @fetcher ->
        {:ok, config}
      end)

      assert Client.get_value(client, feature, "default") == value
    end

    test "does not reload configuration if cache has not expired", %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300))

      MockFetcher
      |> stub(:fetch, fn @fetcher -> {:ok, config} end)

      Client.force_refresh(client)

      MockFetcher
      |> expect(:fetch, 0, fn @fetcher -> {:ok, :unchanged} end)

      Client.get_all_keys(client)
    end

    test "refetches configuration if cache has expired", %{config: config} do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 0))

      MockFetcher
      |> stub(:fetch, fn @fetcher -> {:ok, config} end)

      Client.force_refresh(client)

      MockFetcher
      |> expect(:fetch, 1, fn @fetcher -> {:ok, :unchanged} end)

      Client.get_all_keys(client)
    end
  end

  describe "looking up configuration values" do
    test "looks up the value for a key in the cached config", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} = start_client(initial_config: config, fetch_policy: FetchPolicy.manual())

      assert Client.get_value(client, feature, "default") == value
    end

    test "returns default value when config hasn't been fetched" do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      assert Client.get_value(client, "any_feature", "default") == "default"
    end
  end

  describe "all keys" do
    test "returns all known keys from the cached config", %{config: config, feature: feature} do
      {:ok, client} = start_client(initial_config: config, fetch_policy: FetchPolicy.manual())

      assert Client.get_all_keys(client) == [feature]
    end

    test "returns an empty list of keys when config hasn't been fetched" do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())

      assert Client.get_all_keys(client) == []
    end
  end

  describe "get_variation_id" do
    test "" do
      {:ok, client} = start_client(fetch_policy: FetchPolicy.manual())
      assert Client.get_variation_id(client, "any_feature", "default") == "default"
    end
  end

  defp start_client(options) do
    name = UUID.uuid4() |> String.to_atom()
    options = Keyword.merge([fetcher_api: MockFetcher, fetcher: @fetcher, name: name], options)
    {:ok, _pid} = Client.start_link(options)

    {:ok, name}
  end
end
