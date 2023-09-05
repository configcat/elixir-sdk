defmodule ConfigCat.ConfigFetcherTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CacheControlConfigFetcher, as: ConfigFetcher
  alias ConfigCat.ConfigEntry
  alias ConfigCat.ConfigFetcher.FetchError
  alias ConfigCat.FetchTime
  alias ConfigCat.Hooks
  alias ConfigCat.MockAPI
  alias HTTPoison.Response

  require ConfigCat.Constants, as: Constants

  setup :verify_on_exit!

  @config %{"key" => "value"}
  @etag "ETAG"
  @mode "m"
  @raw_config Jason.encode!(@config)
  @sdk_key "SDK_KEY"
  @fetcher_options %{mode: @mode, sdk_key: @sdk_key}

  defp start_fetcher(%{mode: mode, sdk_key: sdk_key}, options \\ []) do
    instance_id = UUID.uuid4() |> String.to_atom()

    start_supervised!({Hooks, instance_id: instance_id})

    default_options = [api: MockAPI, mode: mode, instance_id: instance_id, sdk_key: sdk_key]

    {:ok, pid} = start_supervised({ConfigFetcher, Keyword.merge(default_options, options)})

    allow(MockAPI, self(), pid)

    {:ok, instance_id}
  end

  test "successful fetch" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    url = global_config_url()

    MockAPI
    |> stub(:get, fn ^url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: @raw_config, headers: [{"ETag", @etag}]}}
    end)

    before = FetchTime.now_ms()

    assert {:ok,
            %ConfigEntry{
              config: @config,
              etag: @etag,
              fetch_time_ms: fetch_time_ms,
              raw_config: @raw_config
            }} = ConfigFetcher.fetch(fetcher, nil)

    assert before <= fetch_time_ms && fetch_time_ms <= FetchTime.now_ms()
  end

  test "user agent header that includes the fetch mode" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{status_code: 200, body: @raw_config}

    MockAPI
    |> stub(:get, fn _url, headers, _options ->
      assert_user_agent_matches(headers, ~r"^ConfigCat-Elixir/#{@mode}-")

      {:ok, response}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher, nil)
  end

  test "sends proper cache control header on later requests" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    initial_response = %Response{
      status_code: 200,
      body: @raw_config,
      headers: [{"ETag", @etag}]
    }

    MockAPI
    |> stub(:get, fn _url, headers, _options ->
      assert List.keyfind(headers, "ETag", 0) == nil
      {:ok, initial_response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher, nil)

    not_modified_response = %Response{
      status_code: 304,
      headers: [{"ETag", @etag}]
    }

    MockAPI
    |> expect(:get, fn _url, headers, _options ->
      assert {"If-None-Match", @etag} = List.keyfind(headers, "If-None-Match", 0)
      {:ok, not_modified_response}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher, @etag)
  end

  test "returns unchanged response when server responds that the config hasn't changed" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{
      status_code: 304,
      headers: [{"ETag", @etag}]
    }

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

    assert {:ok, :unchanged} = ConfigFetcher.fetch(fetcher, @etag)
  end

  @tag capture_log: true
  test "returns error for non-200 response from ConfigCat" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{status_code: 503}

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:ok, response} end)

    assert {:error, %FetchError{reason: ^response}} = ConfigFetcher.fetch(fetcher, nil)
  end

  @tag capture_log: true
  test "returns error for error response from ConfigCat" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    error = %HTTPoison.Error{reason: "failed"}

    MockAPI
    |> stub(:get, fn _url, _headers, _options -> {:error, error} end)

    assert {:error, %FetchError{reason: ^error}} = ConfigFetcher.fetch(fetcher, nil)
  end

  test "allows base URL to be configured" do
    # the extra "/" at the end is intentional, to make sure it works regardless.
    base_url = "https://BASE_URL/"
    {:ok, fetcher} = start_fetcher(@fetcher_options, base_url: base_url)

    url = config_url(base_url, @sdk_key)

    MockAPI
    |> expect(:get, fn ^url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: @raw_config}}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher, nil)
  end

  test "uses default timeouts if none provided" do
    {:ok, fetcher} = start_fetcher(@fetcher_options)

    response = %Response{status_code: 200, body: @raw_config}

    MockAPI
    |> expect(:get, fn _url, _headers, options ->
      assert Keyword.get(options, :recv_timeout) == 5000
      assert Keyword.get(options, :timeout) == 8000
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher, nil)
  end

  test "uses specified timeouts when provided" do
    connect_timeout = 4000
    read_timeout = 2000

    {:ok, fetcher} =
      start_fetcher(@fetcher_options,
        connect_timeout_milliseconds: connect_timeout,
        read_timeout_milliseconds: read_timeout
      )

    response = %Response{status_code: 200, body: @raw_config}

    MockAPI
    |> expect(:get, fn _url, _headers, options ->
      assert Keyword.get(options, :recv_timeout) == read_timeout
      assert Keyword.get(options, :timeout) == connect_timeout
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher, nil)
  end

  test "sends http proxy options when provided" do
    proxy = "https://PROXY"
    {:ok, fetcher} = start_fetcher(@fetcher_options, http_proxy: proxy)

    response = %Response{status_code: 200, body: @raw_config}

    MockAPI
    |> expect(:get, fn _url, _headers, options ->
      assert Keyword.get(options, :proxy) == proxy
      {:ok, response}
    end)

    {:ok, _} = ConfigFetcher.fetch(fetcher, nil)
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
