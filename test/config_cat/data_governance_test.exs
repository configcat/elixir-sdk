defmodule ConfigCat.ConfigFetcher.DataGovernanceTest do
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
    {:ok,
     %{
       redirect_base_url: "https://redirect.configcat.com",
       forced_base_url: "https://forced.configcat.com",
       custom_base_url: "https://custom.configcat.com",
       etag: "ETAG",
       mode: "m",
       sdk_key: "SDK_KEY"
     }}
  end

  defp start_fetcher(%{mode: mode, sdk_key: sdk_key}, options) do
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

  test "test_sdk_global_organization_global",
       %{sdk_key: sdk_key, redirect_base_url: redirect_base_url} = context do
    global_url = global_config_url(sdk_key)
    eu_url = eu_config_url(sdk_key)
    redirect_url = config_url(redirect_base_url, sdk_key)

    config = stub_response(redirect_base_url, RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(context, data_governance: DataGovernance.global())

    MockAPI
    |> expect(:get, 2, fn ^global_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 0, fn ^redirect_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_eu_organization_global",
       %{sdk_key: sdk_key, redirect_base_url: redirect_base_url} = context do
    global_url = global_config_url(sdk_key)
    eu_url = eu_config_url(sdk_key)
    redirect_url = config_url(redirect_base_url, sdk_key)

    config = stub_response(redirect_base_url, RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(context, data_governance: DataGovernance.eu_only())

    MockAPI
    |> expect(:get, 0, fn ^global_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 2, fn ^eu_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 0, fn ^redirect_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_global_organization_eu_only",
       %{sdk_key: sdk_key} = context do
    global_url = global_config_url(sdk_key)
    eu_url = eu_config_url(sdk_key)

    config_to_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.should_redirect())
    config_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(context, data_governance: DataGovernance.global())

    MockAPI
    |> expect(:get, 1, fn ^global_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)
    |> expect(:get, 2, fn ^eu_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config_eu}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_eu_organization_eu_only",
       %{sdk_key: sdk_key} = context do
    global_url = global_config_url(sdk_key)
    eu_url = eu_config_url(sdk_key)

    config_to_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.should_redirect())
    config_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(context, data_governance: DataGovernance.eu_only())

    MockAPI
    |> expect(:get, 0, fn ^global_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)
    |> expect(:get, 2, fn ^eu_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config_eu}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_global_custom_base_url",
       %{sdk_key: sdk_key, custom_base_url: custom_base_url} = context do
    global_url = global_config_url(sdk_key)
    eu_url = eu_config_url(sdk_key)
    custom_url = config_url(custom_base_url, sdk_key)

    config_to_global = stub_response(Constants.base_url_global(), RedirectMode.no_redirect())

    {:ok, fetcher} =
      start_fetcher(context, data_governance: DataGovernance.global(), base_url: custom_base_url)

    MockAPI
    |> expect(:get, 2, fn ^custom_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config_to_global}}
    end)
    |> expect(:get, 0, fn ^global_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

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

    redirect_url = config_url(redirect_path, sdk_key)

    # First call: call global, calls should be made normally
    MockAPI
    |> expect(:get, 1, fn ^eu_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 1, fn ^redirect_url, _headers, [] ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
  end

  defp stub_response(response_uri, redirect) do
    %{
      "f" => %{"test" => "json"},
      Constants.preferences() => %{
        Constants.preferences_base_url() => response_uri,
        Constants.redirect() => redirect
      }
    }
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
end
