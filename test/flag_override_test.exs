defmodule ConfigCat.FlagOverrideTest do
  use ConfigCat.ClientCase, async: true

  import Jason.Sigil

  alias ConfigCat.Config
  alias ConfigCat.FetchTime
  alias ConfigCat.LocalFileDataSource
  alias ConfigCat.LocalMapDataSource
  alias ConfigCat.NullDataSource
  alias ConfigCat.User

  @moduletag capture_log: true

  setup do
    settings = ~J"""
      {
        "fakeKey": {"v": {"b": false}, "t": 0}
      }
    """

    config = Config.new(settings: settings)
    stub_cached_config({:ok, config, FetchTime.now_ms()})

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

  for {key, user_id, email, override_behaviour, expected_value} <- [
        {"stringDependsOnString", "1", "john@sensitivecompany.com", nil, "Dog"},
        {"stringDependsOnString", "1", "john@sensitivecompany.com", :remote_over_local, "Dog"},
        {"stringDependsOnString", "1", "john@sensitivecompany.com", :local_over_remote, "Dog"},
        {"stringDependsOnString", "1", "john@sensitivecompany.com", :local_only, nil},
        {"stringDependsOnString", "2", "john@notsensitivecompany.com", nil, "Cat"},
        {"stringDependsOnString", "2", "john@notsensitivecompany.com", :remote_over_local, "Cat"},
        {"stringDependsOnString", "2", "john@notsensitivecompany.com", :local_over_remote, "Dog"},
        {"stringDependsOnString", "2", "john@notsensitivecompany.com", :local_only, nil},
        {"stringDependsOnInt", "1", "john@sensitivecompany.com", nil, "Dog"},
        {"stringDependsOnInt", "1", "john@sensitivecompany.com", :remote_over_local, "Dog"},
        {"stringDependsOnInt", "1", "john@sensitivecompany.com", :local_over_remote, "Cat"},
        {"stringDependsOnInt", "1", "john@sensitivecompany.com", :local_only, nil},
        {"stringDependsOnInt", "2", "john@notsensitivecompany.com", nil, "Cat"},
        {"stringDependsOnInt", "2", "john@notsensitivecompany.com", :remote_over_local, "Cat"},
        {"stringDependsOnInt", "2", "john@notsensitivecompany.com", :local_over_remote, "Dog"},
        {"stringDependsOnInt", "2", "john@notsensitivecompany.com", :local_only, nil}
      ] do
    @tag skip: "Conflicting SDK Key"
    test "prerequisite flag override with key: #{key} user_id: #{user_id} email: #{email} override behaviour: #{inspect(override_behaviour)}" do
      # The flag override alters the definition of the following flags:
      # * 'mainStringFlag': to check the case where a prerequisite flag is
      #   overridden (dependent flag: 'stringDependsOnString')
      # * 'stringDependsOnInt': to check the case where a dependent flag is
      #   overridden (prerequisite flag: 'mainIntFlag')
      key = unquote(key)
      user_id = unquote(user_id)
      email = unquote(email)
      override_behaviour = unquote(override_behaviour)
      expected_value = unquote(expected_value)

      user = User.new(user_id, email: email)

      overrides =
        if override_behaviour do
          LocalFileDataSource.new(fixture_file("test_override_flagdependency_v6.json"), override_behaviour)
        else
          NullDataSource.new()
        end

      {:ok, client} =
        start_config_cat("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg", flag_overrides: overrides)

      assert expected_value == ConfigCat.get_value(key, nil, user, client: client)
    end
  end

  for {key, user_id, email, override_behaviour, expected_value} <- [
        {"developerAndBetaUserSegment", "1", "john@example.com", nil, false},
        {"developerAndBetaUserSegment", "1", "john@example.com", :remote_over_local, false},
        {"developerAndBetaUserSegment", "1", "john@example.com", :local_over_remote, true},
        {"developerAndBetaUserSegment", "1", "john@example.com", :local_only, true},
        {"notDeveloperAndNotBetaUserSegment", "2", "kate@example.com", nil, true},
        {"notDeveloperAndNotBetaUserSegment", "2", "kate@example.com", :remote_over_local, true},
        {"notDeveloperAndNotBetaUserSegment", "2", "kate@example.com", :local_over_remote, true},
        {"notDeveloperAndNotBetaUserSegment", "2", "kate@example.com", :local_only, nil}
      ] do
    test "salt/segment override with key: #{key} user_id: #{user_id} email: #{email} override behaviour: #{inspect(override_behaviour)}" do
      # The flag override uses a different config json salt than the downloaded one and
      # overrides the following segments:
      # * "Beta Users": User.Email IS ONE OF ["jane@example.com"]
      # * "Developers": User.Email IS ONE OF ["john@example.com"]
      key = unquote(key)
      user_id = unquote(user_id)
      email = unquote(email)
      override_behaviour = unquote(override_behaviour)
      expected_value = unquote(expected_value)

      user = User.new(user_id, email: email)

      overrides =
        if override_behaviour do
          LocalFileDataSource.new(fixture_file("test_override_segments_v6.json"), override_behaviour)
        else
          NullDataSource.new()
        end

      {:ok, client} =
        start_config_cat("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/h99HYXWWNE2bH8eWyLAVMA", flag_overrides: overrides)

      assert expected_value == ConfigCat.get_value(key, nil, user, client: client)
    end
  end

  # defp start_config_cat(sdk_key, options) do
  #   name = String.to_atom(UUID.uuid4())

  #   default_options = [
  #     fetch_policy: CachePolicy.lazy(cache_refresh_interval_seconds: 300),
  #     name: name,
  #     sdk_key: sdk_key
  #   ]

  #   start_supervised!({ConfigCat, Keyword.merge(default_options, options)})
  #   {:ok, name}
  # end

  defp temporary_file(name) do
    dir = System.tmp_dir!()
    filename = Path.join(dir, name)
    on_exit(fn -> File.rm!(filename) end)

    filename
  end
end
