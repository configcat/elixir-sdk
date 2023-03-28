defmodule ConfigCat.ConfigFetcherTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CacheControlConfigFetcher, as: ConfigFetcher
  alias ConfigCat.{Constants, MockAPI}
  alias HTTPoison.Response

  require ConfigCat.{Constants}

  setup :verify_on_exit!

  @config %{"key" => "value"}
  @etag "ETAG"
  @mode "m"
  @sdk_key "SDK_KEY"
  @fetcher_options %{mode: @mode, sdk_key: @sdk_key}

  defp start_fetcher(%{mode: mode, sdk_key: sdk_key}, options \\ []) do
    name = UUID.uuid4() |> String.to_atom()
    default_options = [api: MockAPI, mode: mode, name: name, sdk_key: sdk_key]

    {:ok, _pid} = start_supervised({ConfigFetcher, Keyword.merge(default_options, options)})

    allow(MockAPI, self(), name)

    {:ok, name}
  end

  test "successful fetch" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    url = global_config_url()

    MockAPI
    |> stub(:get, fn ^url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: @config}}
    end)

    assert {:ok, @config} = ConfigFetcher.fetch(fetcher)
  end

  test "user agent header that includes the fetch mode" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{status_code: 200, body: @config}

    MockAPI
    |> stub(:get, fn _url, headers, _options ->
      assert_user_agent_matches(headers, ~r"^ConfigCat-Elixir/#{@mode}-")

      {:ok, response}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "sends proper cache control header on later requests" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    initial_response = %Response{
      status_code: 200,
      body: @config,
      headers: [{"ETag", @etag}]
    }

    MockAPI
    |> stub(:get, fn _url, headers, _options ->
      assert List.keyfind(headers, "ETag", 0) == nil
      {:ok, initial_response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)

    not_modified_response = %Response{
      status_code: 304,
      headers: [{"ETag", @etag}]
    }

    MockAPI
    |> expect(:get, fn _url, headers, _options ->
      assert {"If-None-Match", @etag} = List.keyfind(headers, "If-None-Match", 0)
      {:ok, not_modified_response}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "returns unchanged response when server responds that the config hasn't changed" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{
      status_code: 304,
      headers: [{"ETag", @etag}]
    }

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

    assert {:ok, :unchanged} = ConfigFetcher.fetch(fetcher)
  end

  @tag capture_log: true
  test "returns error for non-200 response from ConfigCat" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{status_code: 503}

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

    assert {:error, ^response} = ConfigFetcher.fetch(fetcher)
  end

  @tag capture_log: true
  test "returns error for error response from ConfigCat" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    error = %HTTPoison.Error{reason: "failed"}

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:error, error} end)

    assert {:error, ^error} = ConfigFetcher.fetch(fetcher)
  end

  test "allows base URL to be configured" do
    # the extra "/" at the end is intentional, to make sure it works regardless.
    base_url = "https://BASE_URL/"
    {:ok, fetcher} = start_fetcher(@fetcher_options, base_url: base_url)

    url = config_url(base_url, @sdk_key)

    MockAPI
    |> expect(:get, fn ^url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: @config}}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "uses default timeouts if none provided" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{status_code: 200, body: @config}

    MockAPI
    |> expect(:get, fn _url, _headers, options ->
      assert Keyword.get(options, :recv_timeout) == 5000
      assert Keyword.get(options, :timeout) == 8000
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "uses specified timeouts when provided" do
    connect_timeout = 4000
    read_timeout = 2000

    {:ok, fetcher} =
      start_fetcher(@fetcher_options,
        connect_timeout_milliseconds: connect_timeout,
        read_timeout_milliseconds: read_timeout
      )

    response = %Response{status_code: 200, body: @config}

    MockAPI
    |> expect(:get, fn _url, _headers, options ->
      assert Keyword.get(options, :recv_timeout) == read_timeout
      assert Keyword.get(options, :timeout) == connect_timeout
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "sends http proxy options when provided" do
    proxy = "https://PROXY"
    {:ok, fetcher} = start_fetcher(@fetcher_options, http_proxy: proxy)

    response = %Response{status_code: 200, body: @config}

    MockAPI
    |> expect(:get, fn _url, _headers, options ->
      assert Keyword.get(options, :proxy) == proxy
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  defp global_config_url(sdk_key \\ @sdk_key) do
    config_url(Constants.base_url_global(), sdk_key)
  end

  defp config_url(base_url, sdk_key) do
    base_url
    |> URI.parse()
    |> URI.merge("#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}")
    |> URI.to_string()
  end

  defp assert_user_agent_matches(headers, expected) do
    {_key, user_agent} = List.keyfind(headers, "User-Agent", 0)
    {_key, x_user_agent} = List.keyfind(headers, "X-ConfigCat-UserAgent", 0)
    assert user_agent =~ expected
    assert x_user_agent =~ expected
  end
end
