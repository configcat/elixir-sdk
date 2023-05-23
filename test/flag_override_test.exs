defmodule ConfigCat.FlagOverrideTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.Client
  alias ConfigCat.LocalFileDataSource
  alias ConfigCat.LocalMapDataSource
  alias ConfigCat.MockCachePolicy

  @moduletag capture_log: true

  @cache_policy_id :cache_policy_id

  setup do
    config = Jason.decode!(~s(
      {
        "p": {"u": "https://cdn-global.configcat.com", "r": 0},
        "f": {
          "fakeKey": {"v": false, "t": 0, "p": [],"r": []}
        }
      }
    ))

    MockCachePolicy
    |> stub(:get, fn @cache_policy_id -> {:ok, config} end)

    {:ok, config: config}
  end

  describe "local-only mode" do
    test "uses flag values from a local file" do
      filename = fixture_file("test.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(overrides)

      assert Client.get_value(client, "enabledFeature", false) == true
      assert Client.get_value(client, "disabledFeature", true) == false
      assert Client.get_value(client, "intSetting", 0) == 5
      assert Client.get_value(client, "doubleSetting", 0.0) == 3.14
      assert Client.get_value(client, "stringSetting", "") == "test"
    end

    test "uses flag values from a simple-format local file" do
      filename = fixture_file("test_simple.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(overrides)

      assert Client.get_value(client, "enabledFeature", false) == true
      assert Client.get_value(client, "disabledFeature", true) == false
      assert Client.get_value(client, "intSetting", 0) == 5
      assert Client.get_value(client, "doubleSetting", 0.0) == 3.14
      assert Client.get_value(client, "stringSetting", "") == "test"
    end

    test "reloads file when modified" do
      flags = %{"flags" => %{"enabledFeature" => false}}
      filename = temporary_file("simple")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(overrides)

      File.open(filename, [:write], fn file ->
        IO.write(file, Jason.encode!(flags))
      end)

      # Backdate file modification time so that it will be different when we
      # rewrite it below. This avoids having to add a sleep to the test.
      stat = File.stat!(filename, time: :posix)
      File.touch!(filename, stat.mtime - 1)

      assert Client.get_value(client, "enabledFeature", true) == false

      modified_flags = put_in(flags, ["flags", "enabledFeature"], true)

      File.open(filename, [:write], fn file ->
        IO.write(file, Jason.encode!(modified_flags))
      end)

      assert Client.get_value(client, "enabledFeature", false) == true
    end

    test "uses default value if override file doesn't exist" do
      filename = fixture_file("non_existent.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(overrides)

      assert Client.get_value(client, "enabledFeature", false) == false
    end

    test "uses default value if override file is invalid" do
      invalid_contents = ~s({"flags": {"enabledFeature": true}\n)
      filename = temporary_file("invalid.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(overrides)

      File.open(filename, [:write], fn file ->
        IO.write(file, invalid_contents)
      end)

      assert Client.get_value(client, "enabledFeature", false) == false
    end

    test "uses flag values from a map" do
      map = %{
        "enabledFeature" => true,
        "disabledFeature" => false,
        "intSetting" => 5,
        "doubleSetting" => 3.14,
        "stringSetting" => "test"
      }

      overrides = LocalMapDataSource.new(map, :local_only)

      {:ok, client} = start_client(overrides)

      assert Client.get_value(client, "enabledFeature", false) == true
      assert Client.get_value(client, "disabledFeature", true) == false
      assert Client.get_value(client, "intSetting", 0) == 5
      assert Client.get_value(client, "doubleSetting", 0.0) == 3.14
      assert Client.get_value(client, "stringSetting", "") == "test"
    end
  end

  describe "local_over_remote mode" do
    test "overrides remote config values with locally-provided replacements" do
      map = %{
        "fakeKey" => true,
        "nonexisting" => true
      }

      overrides = LocalMapDataSource.new(map, :local_over_remote)

      {:ok, client} = start_client(overrides)

      assert Client.get_value(client, "fakeKey", false) == true
      assert Client.get_value(client, "nonexisting", false) == true
    end
  end

  describe "remote_over_local mode" do
    test "overrides local config values with remote config" do
      map = %{
        "fakeKey" => true,
        "nonexisting" => true
      }

      overrides = LocalMapDataSource.new(map, :remote_over_local)

      {:ok, client} = start_client(overrides)

      assert Client.get_value(client, "fakeKey", true) == false
      assert Client.get_value(client, "nonexisting", false) == true
    end
  end

  defp fixture_file(name) do
    __ENV__.file
    |> Path.dirname()
    |> Path.join("fixtures/" <> name)
  end

  defp temporary_file(name) do
    dir = System.tmp_dir!()
    filename = Path.join(dir, name)
    on_exit(fn -> File.rm!(filename) end)

    filename
  end

  defp start_client(flag_overrides) do
    name = UUID.uuid4() |> String.to_atom()

    options = [
      cache_policy: MockCachePolicy,
      cache_policy_id: @cache_policy_id,
      flag_overrides: flag_overrides,
      name: name
    ]

    {:ok, _pid} = start_supervised({Client, options})

    allow(MockCachePolicy, self(), name)

    {:ok, name}
  end
end
