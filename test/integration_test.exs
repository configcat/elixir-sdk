defmodule ConfigCat.IntegrationTest do
  # Must be async: false to avoid a collision with other tests.
  # Now that we only allow a single ConfigCat instance to use the same SDK key,
  # one of the async tests would fail due to the existing running instance.
  use ExUnit.Case, async: false

  alias ConfigCat.Cache
  alias ConfigCat.CachePolicy
  alias ConfigCat.InMemoryCache

  @sdk_key "PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA"

  test "raises error if SDK key is missing" do
    start_config_cat(nil)
    |> assert_sdk_key_required()
  end

  test "raises error if SDK key is an empty string" do
    start_config_cat("")
    |> assert_sdk_key_required()
  end

  @tag capture_log: true
  test "raises error when starting another instance with the same SDK key" do
    {:ok, _} = start_config_cat(@sdk_key, name: :original)

    assert {:error, {{:EXIT, {error, _stacktrace}}, _spec}} =
             start_config_cat(@sdk_key, name: :duplicate)

    assert %ArgumentError{message: message} = error
    assert message =~ ~r/existing ConfigCat instance/
  end

  test "fetches config" do
    {:ok, client} = start_config_cat(@sdk_key)

    :ok = ConfigCat.force_refresh(client: client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  test "maintains previous configuration when config has not changed between refreshes" do
    {:ok, client} = start_config_cat(@sdk_key)

    :ok = ConfigCat.force_refresh(client: client)
    :ok = ConfigCat.force_refresh(client: client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  test "lazily fetches configuration when using lazy loading" do
    {:ok, client} =
      start_config_cat(
        @sdk_key,
        fetch_policy: CachePolicy.lazy(cache_refresh_interval_seconds: 5)
      )

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  @tag capture_log: true
  test "does not fetch config when offline mode is set" do
    {:ok, client} = start_config_cat(@sdk_key, offline: true)

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
    {:ok, client} = start_config_cat("invalid_sdk_key")

    assert {:error, _message} = ConfigCat.force_refresh(client: client)
  end

  @tag capture_log: true
  test "handles invalid base_url" do
    {:ok, client} = start_config_cat(@sdk_key, base_url: "https://invalidcdn.configcat.com")

    assert {:error, _message} = ConfigCat.force_refresh(client: client)
  end

  @tag capture_log: true
  test "handles data_governance: eu_only" do
    {:ok, client} = start_config_cat(@sdk_key, data_governance: :eu_only)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  @tag capture_log: true
  test "handles timeout" do
    {:ok, client} =
      start_config_cat(@sdk_key, connect_timeout_milliseconds: 0, read_timeout_milliseconds: 0)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "default value"
  end

  defp start_config_cat(sdk_key, options \\ []) do
    sdk_key
    |> Cache.generate_key()
    |> InMemoryCache.clear()

    name = UUID.uuid4() |> String.to_atom()
    default_options = [name: name, sdk_key: sdk_key]

    with {:ok, _pid} <-
           start_supervised({ConfigCat, Keyword.merge(default_options, options)}, id: name) do
      {:ok, name}
    end
  end

  defp assert_sdk_key_required({:error, result}) do
    assert {{:EXIT, {error, _stacktrace}}, _spec} = result

    assert %ArgumentError{message: "SDK Key is required"} = error
  end
end
