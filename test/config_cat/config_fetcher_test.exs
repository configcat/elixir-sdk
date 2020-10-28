defmodule ConfigCat.ConfigFetcherTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CacheControlConfigFetcher, as: ConfigFetcher
  alias ConfigCat.{Constants, DataGovernance, MockAPI}
  alias ConfigCat.ConfigFetcher.RedirectMode
  alias HTTPoison.Response

  require ConfigCat.{Constants, DataGovernance}
  require ConfigCat.ConfigFetcher.RedirectMode

  setup :verify_on_exit!

  setup do
    config = %{"key" => "value"}

    config_with_redirect =
      Map.merge(config, %{
        Constants.preferences() => %{
          Constants.preferences_base_url() => "https://redirect.configcat.com",
          Constants.redirect() => RedirectMode.should_redirect()
        }
      })

    config_with_force_redirect =
      Map.merge(config, %{
        Constants.preferences() => %{
          Constants.preferences_base_url() => "https://force.configcat.com",
          Constants.redirect() => RedirectMode.force_redirect()
        }
      })

    etag = "ETAG"
    mode = "m"
    sdk_key = "SDK_KEY"

    {:ok,
     %{
       config: config,
       config_with_redirect: config_with_redirect,
       config_with_force_redirect: config_with_force_redirect,
       etag: etag,
       mode: mode,
       sdk_key: sdk_key
     }}
  end

  defp start_fetcher(%{mode: mode, sdk_key: sdk_key}, options \\ []) do
    name = UUID.uuid4() |> String.to_atom()
    default_options = [api: MockAPI, mode: mode, name: name, sdk_key: sdk_key]
    options = Keyword.merge(default_options, options)

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

  describe "datagovernance behaviour" do
    test "EU with redirection",
         %{config_with_redirect: config, sdk_key: sdk_key} = context do
      {:ok, fetcher} = start_fetcher(context, data_governance: DataGovernance.eu_only())

      eu_url = eu_config_url(sdk_key)

      redirect_path =
        Map.get(config, Constants.preferences())
        |> Map.get(Constants.preferences_base_url())

      redirect_url = config_url(redirect_path, sdk_key)

      # First call: call global-eu, then redirect
      MockAPI
      |> expect(:get, 1, fn ^eu_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)
      |> expect(:get, 1, fn ^redirect_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)

      # Second call: only the redirected URL
      MockAPI
      |> expect(:get, 0, fn ^eu_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)
      |> expect(:get, 1, fn ^redirect_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    end

    test "redirection with custom endpoint",
         %{config_with_redirect: config, sdk_key: sdk_key} = context do
      base_url = "https://custom.service.net"

      {:ok, fetcher} =
        start_fetcher(context, data_governance: DataGovernance.eu_only(), base_url: base_url)

      custom_url = config_url(base_url, sdk_key)
      eu_url = eu_config_url(sdk_key)

      redirect_path =
        Map.get(config, Constants.preferences())
        |> Map.get(Constants.preferences_base_url())

      redirect_url = config_url(redirect_path, sdk_key)

      # First call: call custom, no call should be made to the eu endpoint or the redirect one
      MockAPI
      |> expect(:get, 1, fn ^custom_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)
      |> expect(:get, 0, fn ^eu_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)
      |> expect(:get, 0, fn ^redirect_url, _headers, [] ->
        {:ok, %Response{status_code: 200, body: config}}
      end)

      assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    end

    test "redirection with force redirect",
         %{config_with_force_redirect: config, sdk_key: sdk_key} = context do
      {:ok, fetcher} = start_fetcher(context, data_governance: DataGovernance.eu_only())

      eu_url = eu_config_url(sdk_key)

      redirect_path =
        Map.get(config, Constants.preferences())
        |> Map.get(Constants.preferences_base_url())

      redirect_url =
        config_url(redirect_path, sdk_key)

        # First call: call global, no call should be made to the eu endpoint or the redirect one
        MockAPI
        |> expect(:get, 1, fn ^eu_url, _headers, [] ->
          {:ok, %Response{status_code: 200, body: config}}
        end)
        |> expect(:get, 1, fn ^redirect_url, _headers, [] ->
          {:ok, %Response{status_code: 200, body: config}}
        end)

      assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    end
  end

  defp global_config_url(sdk_key) do
    config_url(Constants.base_url_global(), sdk_key)
  end

  defp eu_config_url(sdk_key) do
    config_url(Constants.base_url_eu_only(), sdk_key)
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
