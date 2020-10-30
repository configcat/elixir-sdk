defmodule ConfigCat.ConfigFetcherTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CacheControlConfigFetcher, as: ConfigFetcher
  alias ConfigCat.{Constants, MockAPI}
  alias HTTPoison.Response

  require ConfigCat.{Constants}

  setup :verify_on_exit!

  setup do
    config = %{"key" => "value"}
    etag = "ETAG"
    mode = "m"
    sdk_key = "SDK_KEY"

    {:ok,
     %{
       config: config,
       etag: etag,
       mode: mode,
       sdk_key: sdk_key
     }}
  end

  defp start_fetcher(%{mode: mode, sdk_key: sdk_key}, options \\ []) do
    name = UUID.uuid4() |> String.to_atom()
    default_options = [api: MockAPI, mode: mode, name: name, sdk_key: sdk_key]

    {:ok, _pid} =
      default_options
      |> Keyword.merge(options)
      |> ConfigFetcher.start_link()

    allow(MockAPI, self(), name)

    {:ok, name}
  end

  test "successful fetch", %{config: config, sdk_key: sdk_key} = context do
    {:ok, fetcher} = start_fetcher(context)

    url = global_config_url(sdk_key)

    MockAPI
    |> stub(:get, fn ^url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
  end

  test "user agent header that includes the fetch mode",
       %{config: config, mode: mode} = context do
    {:ok, fetcher} = start_fetcher(context)

    response = %Response{status_code: 200, body: config}

    MockAPI
    |> stub(:get, fn _url, headers, _options ->
      assert_user_agent_matches(headers, ~r"^ConfigCat-Elixir/#{mode}-")

      {:ok, response}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "sends proper cache control header on later requests",
       %{config: config, etag: etag} = context do
    {:ok, fetcher} = start_fetcher(context)

    initial_response = %Response{
      status_code: 200,
      body: config,
      headers: [{"ETag", etag}]
    }

    MockAPI
    |> stub(:get, fn _url, headers, _options ->
      assert List.keyfind(headers, "ETag", 0) == nil
      {:ok, initial_response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)

    not_modified_response = %Response{
      status_code: 304,
      headers: [{"ETag", etag}]
    }

    MockAPI
    |> expect(:get, fn _url, headers, _options ->
      assert {"If-None-Match", ^etag} = List.keyfind(headers, "If-None-Match", 0)
      {:ok, not_modified_response}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "returns unchanged response when server responds that the config hasn't changed",
       %{etag: etag} = context do
    {:ok, fetcher} = start_fetcher(context)

    response = %Response{
      status_code: 304,
      headers: [{"ETag", etag}]
    }

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

    assert {:ok, :unchanged} = ConfigFetcher.fetch(fetcher)
  end

  @tag capture_log: true
  test "returns error for non-200 response from ConfigCat", context do
    {:ok, fetcher} = start_fetcher(context)

    response = %Response{status_code: 503}

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

    assert {:error, ^response} = ConfigFetcher.fetch(fetcher)
  end

  @tag capture_log: true
  test "returns error for error response from ConfigCat", context do
    {:ok, fetcher} = start_fetcher(context)

    error = %HTTPoison.Error{reason: "failed"}

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:error, error} end)

    assert {:error, ^error} = ConfigFetcher.fetch(fetcher)
  end

  test "allows base URL to be configured", %{config: config, sdk_key: sdk_key} = context do
    base_url = "https://BASE_URL"
    {:ok, fetcher} = start_fetcher(context, base_url: base_url)

    url = config_url(base_url, sdk_key)

    MockAPI
    |> expect(:get, fn ^url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "sends http proxy options when provided", %{config: config} = context do
    proxy = "https://PROXY"
    {:ok, fetcher} = start_fetcher(context, http_proxy: proxy)

    response = %Response{status_code: 200, body: config}

    MockAPI
    |> expect(:get, fn _url, _headers, [proxy: ^proxy] ->
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  defp global_config_url(sdk_key) do
    config_url(Constants.base_url_global(), sdk_key)
  end

  defp config_url(base_url, sdk_key) do
    "#{base_url}/#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}"
  end

  defp assert_user_agent_matches(headers, expected) do
    {_key, user_agent} = List.keyfind(headers, "User-Agent", 0)
    {_key, x_user_agent} = List.keyfind(headers, "X-ConfigCat-UserAgent", 0)
    assert user_agent =~ expected
    assert x_user_agent =~ expected
  end
end
