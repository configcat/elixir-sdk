defmodule ConfigCat.IntegrationTest do
  # Must be async: false to avoid a collision with other tests.
  # Now that we only allow a single ConfigCat instance to use the same SDK key,
  # one of the async tests would fail due to the existing running instance.
  use ConfigCat.Case, async: false

  alias ConfigCat.Cache
  alias ConfigCat.CachePolicy
  alias ConfigCat.InMemoryCache
  alias ConfigCat.LocalMapDataSource

  @sdk_key "PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA"

  describe "SDK key validation" do
    test "raises error if SDK key is missing" do
      nil
      |> start()
      |> assert_sdk_key_required()
    end

    test "raises error if SDK key is an empty string" do
      ""
      |> start()
      |> assert_sdk_key_required()
    end

    for sdk_key <- [
          "key",
          "configcat-proxy/key",
          "1234567890abcdefghijkl01234567890abcdefghijkl",
          "configcat-sdk-2/1234567890abcdefghijkl/1234567890abcdefghijkl",
          "configcat/1234567890abcdefghijkl/1234567890abcdefghijkl"
        ] do
      test "raises error if SDK is invalid with SDK key: #{sdk_key}" do
        sdk_key = unquote(sdk_key)

        sdk_key |> start() |> assert_sdk_key_invalid(sdk_key)
      end
    end

    test "allows older format SDK keys" do
      assert {:ok, _} = start("1234567890abcdefghijkl/1234567890abcdefghijkl")
    end

    test "allows newer format SDK keys" do
      assert {:ok, _} = start("configcat-sdk-1/1234567890abcdefghijkl/1234567890abcdefghijkl")
    end

    test "allows proxy SDK keys if base_url is specified" do
      assert {:ok, _} = start("configcat-proxy/key", base_url: "base_url")
    end

    test "does not allow non-proxy SDK keys even if base_url is specified" do
      sdk_key = "not-configcat-proxy/key"
      sdk_key |> start(base_url: "base_url") |> assert_sdk_key_invalid(sdk_key)
    end

    test "does not validate SDK key format in local-only mode" do
      overrides = LocalMapDataSource.new(%{}, :local_only)
      assert {:ok, _} = start("invalid-sdk-key-format", flag_overrides: overrides)
    end

    @tag capture_log: true
    test "raises error when starting another instance with the same SDK key" do
      {:ok, _} = start(@sdk_key, name: :original)

      assert {:error, {{:EXIT, {error, _stacktrace}}, _spec}} =
               start(@sdk_key, name: :duplicate)

      assert %ArgumentError{message: message} = error
      assert message =~ ~r/existing ConfigCat instance/
    end
  end

  test "fetches config" do
    {:ok, client} = start(@sdk_key)

    :ok = ConfigCat.force_refresh(client: client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  test "maintains previous configuration when config has not changed between refreshes" do
    {:ok, client} = start(@sdk_key)

    :ok = ConfigCat.force_refresh(client: client)
    :ok = ConfigCat.force_refresh(client: client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  test "lazily fetches configuration when using lazy loading" do
    {:ok, client} =
      start(
        @sdk_key,
        fetch_policy: CachePolicy.lazy(cache_refresh_interval_seconds: 5)
      )

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  @tag capture_log: true
  test "does not fetch config when offline mode is set" do
    {:ok, client} = start(@sdk_key, offline: true)

    assert ConfigCat.offline?(client: client)

    {:error, _message} = ConfigCat.force_refresh(client: client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "default value"

    :ok = ConfigCat.set_online(client: client)
    refute ConfigCat.offline?(client: client)

    :ok = ConfigCat.force_refresh(client: client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  @tag capture_log: true
  test "handles errors from ConfigCat server" do
    {:ok, client} = start("configcat-sdk-1/1234567890abcdefghijkl/1234567890abcdefghijkl")

    assert {:error, _message} = ConfigCat.force_refresh(client: client)
  end

  @tag capture_log: true
  test "handles invalid base_url" do
    {:ok, client} = start(@sdk_key, base_url: "https://invalidcdn.configcat.com")

    assert {:error, _message} = ConfigCat.force_refresh(client: client)
  end

  @tag capture_log: true
  test "handles data_governance: eu_only" do
    {:ok, client} = start(@sdk_key, data_governance: :eu_only)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  @tag capture_log: true
  test "handles timeout" do
    {:ok, client} =
      start(@sdk_key, connect_timeout_milliseconds: 0, read_timeout_milliseconds: 0)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "default value"
  end

  defp start(sdk_key, options \\ []) do
    sdk_key
    |> Cache.generate_key()
    |> InMemoryCache.clear()

    start_config_cat(sdk_key, options)
  end

  defp assert_sdk_key_invalid({:error, result}, sdk_key) do
    assert {{:EXIT, {error, _stacktrace}}, _spec} = result

    expected_message = "SDK Key `#{sdk_key}` is invalid."
    assert %ArgumentError{message: ^expected_message} = error
  end

  defp assert_sdk_key_required({:error, result}) do
    assert {{:EXIT, {error, _stacktrace}}, _spec} = result

    assert %ArgumentError{message: "SDK Key is required"} = error
  end
end
