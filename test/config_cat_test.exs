defmodule ConfigCatTest do
  require ConfigCat.Constants

  use ExUnit.Case

  import Mox

  alias ConfigCat.{FetchPolicy, Constants}
  alias HTTPoison.Response

  setup [:set_mox_global, :verify_on_exit!]

  Mox.defmock(APIMock, for: HTTPoison.Base)

  setup do
    feature = "FEATURE"
    value = "VALUE"
    config = %{Constants.feature_flags => %{feature => %{Constants.value => value}}}

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
      url = "https://cdn.configcat.com/#{Constants.base_path}/#{sdk_key}/#{Constants.config_filename}"

      {:ok, client} = start_config_cat(sdk_key, fetch_policy: FetchPolicy.manual())

      APIMock
      |> stub(:get, fn ^url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      :ok = ConfigCat.force_refresh(client)
      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "sends proper user agent header" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())

      response = %Response{status_code: 200, body: %{}}

      APIMock
      |> stub(:get, fn _url, headers, _options ->
        assert_user_agent_matches(headers, ~r"^ConfigCat-Elixir/m-")

        {:ok, response}
      end)

      assert :ok = ConfigCat.force_refresh(client)
    end

    test "sends proper cache control header on later requests" do
      etag = "ETAG"
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())

      initial_response = %Response{
        status_code: 200,
        body: %{},
        headers: [{"ETag", etag}]
      }

      APIMock
      |> stub(:get, fn _url, headers, _options ->
        assert List.keyfind(headers, "ETag", 0) == nil
        {:ok, initial_response}
      end)

      :ok = ConfigCat.force_refresh(client)

      not_modified_response = %Response{
        status_code: 304,
        headers: [{"ETag", etag}]
      }

      APIMock
      |> expect(:get, fn _url, headers, _options ->
        assert {"If-None-Match", ^etag} = List.keyfind(headers, "If-None-Match", 0)
        {:ok, not_modified_response}
      end)

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
      |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

      :ok = ConfigCat.force_refresh(client)

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    @tag capture_log: true
    test "handles non-200 response from ConfigCat" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())
      response = %Response{status_code: 503}

      APIMock
      |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

      assert {:error, response} == ConfigCat.force_refresh(client)
    end

    @tag capture_log: true
    test "handles error response from ConfigCat" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())

      error = %HTTPoison.Error{reason: "failed"}

      APIMock
      |> stub(:get, fn _url, _headers, _options -> {:error, error} end)

      assert {:error, error} == ConfigCat.force_refresh(client)
    end

    test "allows base URL to be configured" do
      base_url = "https://BASE_URL/"
      sdk_key = "SDK_KEY"
      url = "https://BASE_URL/#{Constants.base_path}/#{sdk_key}/#{Constants.config_filename}"

      {:ok, client} =
        start_config_cat(sdk_key, base_url: base_url, fetch_policy: FetchPolicy.manual())

      APIMock
      |> expect(:get, fn ^url, _headers, _options ->
        {:ok, %Response{status_code: 200, body: %{}}}
      end)

      :ok = ConfigCat.force_refresh(client)
    end

    test "sends proper http proxy options" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual(), http_proxy: "https://myproxy.com")

      response = %Response{status_code: 200, body: %{}}

      APIMock
      |> stub(:get, fn _url, _headers, [proxy: "https://myproxy.com"] ->
        {:ok, response}
      end)

      assert :ok = ConfigCat.force_refresh(client)
    end
  end

  describe "automatically fetching the configuration" do
    test "loads configuration after initialized", %{
      config: config,
      feature: feature,
      value: value
    } do
      APIMock
      |> stub(:get, fn _url, _headers, _options ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.auto())

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "sends proper user agent header" do
      APIMock
      |> stub(:get, fn _url, headers, _options ->
        assert_user_agent_matches(headers, ~r"^ConfigCat-Elixir/a-")

        {:ok, %Response{status_code: 200, body: %{}}}
      end)

      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.auto())

      assert :ok = ConfigCat.force_refresh(client)
    end

    test "retains previous configuration if state cannot be refreshed", %{
      feature: feature,
      config: config,
      value: value
    } do
      APIMock
      |> stub(:get, fn _url, _headers, _options ->
        {:ok, %Response{status_code: 500}}
      end)

      {:ok, client} =
        start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.auto(), initial_config: config)

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
      |> stub(:get, fn _url, _headers, _options ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      assert ConfigCat.get_value(feature, "default", client: client) == value
    end

    test "sends proper user agent header" do
      {:ok, client} =
        start_config_cat(
          "SDK_KEY",
          fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300)
        )

      response = %Response{status_code: 200, body: %{}}

      APIMock
      |> stub(:get, fn _url, headers, _options ->
        assert_user_agent_matches(headers, ~r"^ConfigCat-Elixir/l-")

        {:ok, response}
      end)

      assert :ok = ConfigCat.force_refresh(client)
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

      call_times = 2

      APIMock
      |> expect(:get, 1, fn _url, _headers, _options ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      result = Enum.reduce 1..call_times, 0, fn _n, _a ->
        ConfigCat.get_value(feature, "default", client: client)
      end

      assert result == value
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

      call_times = 2

      APIMock
      |> expect(:get, call_times, fn _url, _headers, _options ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      result = Enum.reduce 1..call_times, 0, fn _n, _a ->
        ConfigCat.get_value(feature, "default", client: client)
      end

      assert result == value
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

  describe "get_variation_id" do
    test "" do
      {:ok, client} = start_config_cat("SDK_KEY", fetch_policy: FetchPolicy.manual())
      assert ConfigCat.get_variation_id("any_feature", "default", client: client) == "default"
    end
  end

  defp start_config_cat(sdk_key, options \\ []) do
    name = UUID.uuid4() |> String.to_atom()
    ConfigCat.start_link(sdk_key, Keyword.merge([api: APIMock, name: name], options))
  end

  defp assert_user_agent_matches(headers, expected) do
    {_key, user_agent} = List.keyfind(headers, "User-Agent", 0)
    {_key, x_user_agent} = List.keyfind(headers, "X-ConfigCat-UserAgent", 0)
    assert user_agent =~ expected
    assert x_user_agent =~ expected
  end
end
