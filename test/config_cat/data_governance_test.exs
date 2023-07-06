defmodule ConfigCat.ConfigFetcher.DataGovernanceTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.CacheControlConfigFetcher, as: ConfigFetcher
  alias ConfigCat.ConfigFetcher.RedirectMode
  alias ConfigCat.Constants
  alias ConfigCat.MockAPI
  alias HTTPoison.Response

  require ConfigCat.Constants
  require ConfigCat.ConfigFetcher.RedirectMode

  setup :verify_on_exit!

  @redirect_base_url "https://redirect.configcat.com"
  @forced_base_url "https://forced.configcat.com"
  @custom_base_url "https://custom.configcat.com"
  @mode "m"
  @sdk_key "SDK_KEY"
  @fetcher_options %{mode: @mode, sdk_key: @sdk_key}

  defp start_fetcher(%{mode: mode, sdk_key: sdk_key}, options) do
    instance_id = UUID.uuid4() |> String.to_atom()
    default_options = [api: MockAPI, instance_id: instance_id, mode: mode, sdk_key: sdk_key]

    {:ok, pid} = start_supervised({ConfigFetcher, Keyword.merge(default_options, options)})

    allow(MockAPI, self(), pid)

    {:ok, instance_id}
  end

  test "test_sdk_global_organization_global" do
    global_url = global_config_url()
    eu_url = eu_config_url()
    redirect_url = config_url(@redirect_base_url)

    config = stub_response(@redirect_base_url, RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(@fetcher_options, data_governance: :global)

    MockAPI
    |> expect(:get, 2, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 0, fn ^redirect_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_eu_organization_global" do
    global_url = global_config_url()
    eu_url = eu_config_url()
    redirect_url = config_url(@redirect_base_url)

    config = stub_response(@redirect_base_url, RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(@fetcher_options, data_governance: :eu_only)

    MockAPI
    |> expect(:get, 0, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 2, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config}}
    end)
    |> expect(:get, 0, fn ^redirect_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config}}
    end)

    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
    assert {:ok, ^config} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_global_organization_eu_only" do
    global_url = global_config_url()
    eu_url = eu_config_url()

    config_to_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.should_redirect())
    config_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(@fetcher_options, data_governance: :global)

    MockAPI
    |> expect(:get, 1, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)
    |> expect(:get, 2, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_eu}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_eu_organization_eu_only" do
    global_url = global_config_url()
    eu_url = eu_config_url()

    config_to_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.should_redirect())
    config_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.no_redirect())

    {:ok, fetcher} = start_fetcher(@fetcher_options, data_governance: :eu_only)

    MockAPI
    |> expect(:get, 0, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)
    |> expect(:get, 2, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_eu}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_global_custom_base_url" do
    global_url = global_config_url()
    eu_url = eu_config_url()
    custom_url = config_url(@custom_base_url)

    config_to_global = stub_response(Constants.base_url_global(), RedirectMode.no_redirect())

    {:ok, fetcher} =
      start_fetcher(@fetcher_options,
        data_governance: :global,
        base_url: @custom_base_url
      )

    MockAPI
    |> expect(:get, 2, fn ^custom_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_global}}
    end)
    |> expect(:get, 0, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_eu_custom_base_url" do
    global_url = global_config_url()
    eu_url = eu_config_url()
    custom_url = config_url(@custom_base_url)

    config_to_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.no_redirect())

    {:ok, fetcher} =
      start_fetcher(@fetcher_options,
        data_governance: :eu_only,
        base_url: @custom_base_url
      )

    MockAPI
    |> expect(:get, 2, fn ^custom_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)
    |> expect(:get, 0, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_global_forced" do
    global_url = global_config_url()
    eu_url = eu_config_url()
    forced_url = config_url(@forced_base_url)

    config_to_forced = stub_response(@forced_base_url, RedirectMode.force_redirect())

    {:ok, fetcher} = start_fetcher(@fetcher_options, data_governance: :global)

    MockAPI
    |> expect(:get, 1, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_forced}}
    end)
    |> expect(:get, 2, fn ^forced_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_base_url_forced" do
    global_url = global_config_url()
    eu_url = eu_config_url()
    custom_url = config_url(@custom_base_url)
    forced_url = config_url(@forced_base_url)

    config_to_forced = stub_response(@forced_base_url, RedirectMode.force_redirect())

    {:ok, fetcher} =
      start_fetcher(@fetcher_options,
        data_governance: :global,
        base_url: @custom_base_url
      )

    MockAPI
    |> expect(:get, 0, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)
    |> expect(:get, 0, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: %{}}}
    end)
    |> expect(:get, 1, fn ^custom_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_forced}}
    end)
    |> expect(:get, 3, fn ^forced_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_forced}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  test "test_sdk_redirect_loop" do
    global_url = global_config_url()
    eu_url = eu_config_url()

    config_to_global = stub_response(Constants.base_url_global(), RedirectMode.should_redirect())
    config_to_eu = stub_response(Constants.base_url_eu_only(), RedirectMode.should_redirect())

    {:ok, fetcher} = start_fetcher(@fetcher_options, data_governance: :global)

    MockAPI
    |> expect(:get, 1, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)
    |> expect(:get, 1, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_global}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)

    MockAPI
    |> expect(:get, 1, fn ^eu_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_global}}
    end)
    |> expect(:get, 1, fn ^global_url, _headers, _options ->
      {:ok, %Response{status_code: 200, body: config_to_eu}}
    end)

    assert {:ok, _} = ConfigFetcher.fetch(fetcher)
  end

  defp stub_response(response_uri, redirect) do
    %{
      Constants.preferences() => %{
        Constants.preferences_base_url() => response_uri,
        Constants.redirect() => redirect
      }
    }
  end

  defp global_config_url(sdk_key \\ @sdk_key) do
    config_url(Constants.base_url_global(), sdk_key)
  end

  defp eu_config_url(sdk_key \\ @sdk_key) do
    config_url(Constants.base_url_eu_only(), sdk_key)
  end

  defp config_url(base_url, sdk_key \\ @sdk_key) do
    "#{base_url}/#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}"
  end
end
