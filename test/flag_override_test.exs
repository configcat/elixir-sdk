defmodule ConfigCat.FlagOverrideTest do
  use ConfigCat.ClientCase, async: true

  import Jason.Sigil

  alias ConfigCat.ConfigEntry
  alias ConfigCat.LocalFileDataSource
  alias ConfigCat.LocalMapDataSource

  @moduletag capture_log: true

  setup do
    settings = ~J"""
      {
        "fakeKey": {"v": false, "t": 0, "p": [],"r": []}
      }
    """

    stub_cached_settings({:ok, settings, ConfigEntry.now()})

    :ok
  end

  describe "local-only mode" do
    test "uses flag values from a local file" do
      filename = fixture_file("test.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(flag_overrides: overrides)

      assert ConfigCat.get_value("enabledFeature", false, client: client) == true
      assert ConfigCat.get_value("disabledFeature", true, client: client) == false
      assert ConfigCat.get_value("intSetting", 0, client: client) == 5
      assert ConfigCat.get_value("doubleSetting", 0.0, client: client) == 3.14
      assert ConfigCat.get_value("stringSetting", "", client: client) == "test"
    end

    test "uses flag values from a simple-format local file" do
      filename = fixture_file("test_simple.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(flag_overrides: overrides)

      assert ConfigCat.get_value("enabledFeature", false, client: client) == true
      assert ConfigCat.get_value("disabledFeature", true, client: client) == false
      assert ConfigCat.get_value("intSetting", 0, client: client) == 5
      assert ConfigCat.get_value("doubleSetting", 0.0, client: client) == 3.14
      assert ConfigCat.get_value("stringSetting", "", client: client) == "test"
    end

    test "reloads file when modified" do
      flags = %{"flags" => %{"enabledFeature" => false}}
      filename = temporary_file("simple")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(flag_overrides: overrides)

      File.open(filename, [:write], fn file ->
        IO.write(file, Jason.encode!(flags))
      end)

      # Backdate file modification time so that it will be different when we
      # rewrite it below. This avoids having to add a sleep to the test.
      stat = File.stat!(filename, time: :posix)
      File.touch!(filename, stat.mtime - 1)

      assert ConfigCat.get_value("enabledFeature", true, client: client) == false

      modified_flags = put_in(flags, ["flags", "enabledFeature"], true)

      File.open(filename, [:write], fn file ->
        IO.write(file, Jason.encode!(modified_flags))
      end)

      assert ConfigCat.get_value("enabledFeature", false, client: client) == true
    end

    test "uses default value if override file doesn't exist" do
      filename = fixture_file("non_existent.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(flag_overrides: overrides)

      assert ConfigCat.get_value("enabledFeature", false, client: client) == false
    end

    test "uses default value if override file is invalid" do
      invalid_contents = ~s({"flags": {"enabledFeature": true}\n)
      filename = temporary_file("invalid.json")
      overrides = LocalFileDataSource.new(filename, :local_only)

      {:ok, client} = start_client(flag_overrides: overrides)

      File.open(filename, [:write], fn file ->
        IO.write(file, invalid_contents)
      end)

      assert ConfigCat.get_value("enabledFeature", false, client: client) == false
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

      {:ok, client} = start_client(flag_overrides: overrides)

      assert ConfigCat.get_value("enabledFeature", false, client: client) == true
      assert ConfigCat.get_value("disabledFeature", true, client: client) == false
      assert ConfigCat.get_value("intSetting", 0, client: client) == 5
      assert ConfigCat.get_value("doubleSetting", 0.0, client: client) == 3.14
      assert ConfigCat.get_value("stringSetting", "", client: client) == "test"
    end
  end

  describe "local_over_remote mode" do
    test "overrides remote config values with locally-provided replacements" do
      map = %{
        "fakeKey" => true,
        "nonexisting" => true
      }

      overrides = LocalMapDataSource.new(map, :local_over_remote)

      {:ok, client} = start_client(flag_overrides: overrides)

      assert ConfigCat.get_value("fakeKey", false, client: client) == true
      assert ConfigCat.get_value("nonexisting", false, client: client) == true
    end
  end

  describe "remote_over_local mode" do
    test "overrides local config values with remote config" do
      map = %{
        "fakeKey" => true,
        "nonexisting" => true
      }

      overrides = LocalMapDataSource.new(map, :remote_over_local)

      {:ok, client} = start_client(flag_overrides: overrides)

      assert ConfigCat.get_value("fakeKey", true, client: client) == false
      assert ConfigCat.get_value("nonexisting", false, client: client) == true
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
end
