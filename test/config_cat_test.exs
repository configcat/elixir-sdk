defmodule ConfigCatTest do
  use ExUnit.Case

  import Mox

  alias ConfigCat.FetchPolicy
  alias HTTPoison.Response

  setup [:set_mox_global, :verify_on_exit!]

  Mox.defmock(APIMock, for: HTTPoison.Base)

  setup do
    feature = "FEATURE"
    value = "VALUE"
    config = %{feature => %{"v" => value}}

    {:ok, config: config, feature: feature, value: value}
  end

  describe "starting the GenServer" do
    test "requires SDK key" do
      assert {:error, :missing_sdk_key} == start_config_cat(nil)
    end
  end

  describe "manually fetching the configuration" do
    test "fetches configuration from ConfigCat server", %{
      config: config,
      feature: feature,
      value: value
    } do
      sdk_key = "SDK_KEY"
      url = "https://cdn.configcat.com/configuration-files/#{sdk_key}/config_v4.json"

      {:ok, client} = start_config_cat(sdk_key, fetch_policy: FetchPolicy.manual())

      APIMock
      |> stub(:get, fn ^url, _headers ->
        {:ok, %Response{status_code: 200, body: Jason.encode!(config)}}
      end)

      :ok = ConfigCat.force_refresh(client)
      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "sends proper cache control header on later requests" do
      etag = "ETAG"
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())

      initial_response = %Response{
        status_code: 200,
        body: Jason.encode!(%{}),
        headers: [{"ETag", etag}]
      }

      APIMock
      |> stub(:get, fn _url, [] -> {:ok, initial_response} end)

      :ok = ConfigCat.force_refresh(client)

      not_modified_response = %Response{
        status_code: 304,
        headers: [{"ETag", etag}]
      }

      APIMock
      |> expect(:get, fn _url, [{"If-None-Match", ^etag}] -> {:ok, not_modified_response} end)

      assert :ok = ConfigCat.force_refresh(client)
    end

    test "retains previous config when server responds that the config hasn't changed", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} =
        start_config_cat("SDK_KEY", initial_config: config, fetch_policy: FetchPolicy.manual())

      response = %Response{
        status_code: 304,
        headers: [{"ETag", "ETAG"}]
      }

      APIMock
      |> stub(:get, fn _url, _headers -> {:ok, response} end)

      :ok = ConfigCat.force_refresh(client)

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    @tag capture_log: true
    test "handles non-200 response from ConfigCat" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())
      response = %Response{status_code: 503}

      APIMock
      |> stub(:get, fn _url, _headers -> {:ok, response} end)

      assert {:error, response} == ConfigCat.force_refresh(client)
    end

    @tag capture_log: true
    test "handles error response from ConfigCat" do
      {:ok, client} = start_config_cat("SDK_KEY")

      error = %HTTPoison.Error{reason: "failed"}

      APIMock
      |> stub(:get, fn _url, _headers -> {:error, error} end)

      assert {:error, error} == ConfigCat.force_refresh(client)
    end

    test "allows base URL to be configured" do
      base_url = "https://BASE_URL/"
      sdk_key = "SDK_KEY"
      url = "https://BASE_URL/configuration-files/#{sdk_key}/config_v4.json"

      {:ok, client} =
        start_config_cat(sdk_key, base_url: base_url, fetch_policy: FetchPolicy.manual())

      APIMock
      |> expect(:get, fn ^url, _headers ->
        {:ok, %Response{status_code: 200, body: Jason.encode!(%{})}}
      end)

      :ok = ConfigCat.force_refresh(client)
    end
  end

  describe "automatically fetching the configuration" do
    test "loads configuration after initialized", %{
      config: config,
      feature: feature,
      value: value
    } do
      APIMock
      |> stub(:get, fn _url, _headers ->
        {:ok, %Response{status_code: 200, body: Jason.encode!(config)}}
      end)

      fetch_policy = FetchPolicy.auto()
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: fetch_policy)

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "retains previous configuration if state cannot be refreshed", %{
      feature: feature,
      config: config,
      value: value
    } do
      APIMock
      |> stub(:get, fn _url, _headers ->
        {:ok, %Response{status_code: 500}}
      end)

      fetch_policy = FetchPolicy.auto()

      {:ok, client} =
        start_config_cat("SDK_KEY", fetch_policy: fetch_policy, initial_config: config)

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end
  end

  describe "lazily fetching the configuration" do
    test "loads configuration when first attempting to get a value", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} =
        start_config_cat(
          "SDK_KEY",
          fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300)
        )

      APIMock
      |> stub(:get, fn _url, _headers ->
        {:ok, %Response{status_code: 200, body: Jason.encode!(config)}}
      end)

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "does not reload configuration if cache has not expired", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} =
        start_config_cat(
          "SDK_KEY",
          fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300)
        )

      APIMock
      |> expect(:get, 1, fn _url, _headers ->
        {:ok, %Response{status_code: 200, body: Jason.encode!(config)}}
      end)

      ConfigCat.get_value(feature, "default", client: client)
      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "refetches configuration if cache has expired", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} =
        start_config_cat(
          "SDK_KEY",
          fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 0)
        )

      APIMock
      |> expect(:get, 2, fn _url, _headers ->
        {:ok, %Response{status_code: 200, body: Jason.encode!(config)}}
      end)

      ConfigCat.get_value(feature, "default", client: client)
      assert ConfigCat.get_value(feature, "default", client: client) == value
    end
  end

  describe "looking up configuration values" do
    test "looks up the value for a key in the cached config", %{
      config: config,
      feature: feature,
      value: value
    } do
      {:ok, client} =
        start_config_cat("SDK_KEY", initial_config: config, fetch_policy: FetchPolicy.manual())

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "returns default value when config hasn't been fetched" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())

      assert ConfigCat.get_value("any_feature", "default", client: client) == "default"
    end
  end

  describe "all keys" do
    test "returns all known keys from the cached config", %{config: config, feature: feature} do
      {:ok, client} =
        start_config_cat("SDK_KEY", initial_config: config, fetch_policy: FetchPolicy.manual())

      assert ConfigCat.get_all_keys(client: client) == [feature]
    end

    test "returns an empty list of keys when config hasn't been fetched" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())

      assert ConfigCat.get_all_keys(client: client) == []
    end
  end

  defp start_config_cat(sdk_key, options \\ []) do
    name = UUID.uuid4() |> String.to_atom()
    ConfigCat.start_link(sdk_key, Keyword.merge([api: APIMock, name: name], options))
  end
end
