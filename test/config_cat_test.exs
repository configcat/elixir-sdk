defmodule ConfigCatTest do
  use ConfigCat.ClientCase, async: true

  import ExUnit.CaptureLog
  import Jason.Sigil
  import Mox

  alias ConfigCat.Config
  alias ConfigCat.Config.TargetingRule
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.Factory
  alias ConfigCat.FetchTime
  alias ConfigCat.Hooks
  alias ConfigCat.User

  require ConfigCat.Config.SettingType, as: SettingType

  @moduletag capture_log: true

  setup :verify_on_exit!

  describe "when the configuration has been fetched" do
    setup do
      config = Config.inline_salt_and_segments(Factory.config())

      {:ok, client} = start_client()

      fetch_time_ms = FetchTime.now_ms()
      stub_cached_config({:ok, config, fetch_time_ms})

      {:ok, client: client, fetch_time_ms: fetch_time_ms}
    end

    test "get_all_keys/1 returns all known keys", %{client: client} do
      expected = Enum.sort(~w(testBoolKey testStringKey testIntKey testDoubleKey key1 key2))
      actual = [client: client] |> ConfigCat.get_all_keys() |> Enum.sort()
      assert actual == expected
    end

    test "get_value/4 returns a boolean value", %{client: client} do
      assert ConfigCat.get_value("testBoolKey", false, client: client) == true
    end

    test "get_value/4 returns a string value", %{client: client} do
      assert ConfigCat.get_value("testStringKey", "default", client: client) == "testValue"
    end

    test "get_value/4 returns an integer value", %{client: client} do
      assert ConfigCat.get_value("testIntKey", 0, client: client) == 1
    end

    test "get_value/4 returns a double value", %{client: client} do
      assert ConfigCat.get_value("testDoubleKey", 0.0, client: client) == 1.1
    end

    test "get_value/4 returns default value if key not found", %{client: client} do
      assert ConfigCat.get_value("testUnknownKey", "default", client: client) == "default"
    end

    test "get_key_and_value/2 returns matching key/value pair for a variation id", %{
      client: client
    } do
      assert {"key1", true} = ConfigCat.get_key_and_value("fakeId1", client: client)
      assert {"key2", false} = ConfigCat.get_key_and_value("fakeId2", client: client)
    end

    test "get_all_values/2 returns all key/value pairs", %{client: client} do
      expected =
        Enum.sort(%{
          "testBoolKey" => true,
          "testStringKey" => "testValue",
          "testIntKey" => 1,
          "testDoubleKey" => 1.1,
          "key1" => true,
          "key2" => false
        })

      actual = nil |> ConfigCat.get_all_values(client: client) |> Enum.sort()
      assert actual == expected
    end

    test "get_value_details/4 returns evaluation details", %{
      client: client,
      fetch_time_ms: fetch_time_ms
    } do
      user = User.new("test@test1.com")

      {:ok, fetch_time} = FetchTime.to_datetime(fetch_time_ms)

      assert %EvaluationDetails{
               default_value?: false,
               error: nil,
               fetch_time: ^fetch_time,
               key: "testStringKey",
               matched_targeting_rule: rule,
               matched_percentage_option: nil,
               user: ^user,
               value: "fake1",
               variation_id: "id1"
             } = ConfigCat.get_value_details("testStringKey", "", user, client: client)

      assert TargetingRule.value(rule, SettingType.string()) == "fake1"
      assert TargetingRule.variation_id(rule) == "id1"
    end

    test "get_all_value_details/2 returns evaluation details for all keys", %{client: client} do
      all_details = ConfigCat.get_all_value_details(client: client)
      details_by_key = fn key -> Enum.find(all_details, &(&1.key == key)) end

      assert length(all_details) == 6

      assert %{key: "testBoolKey", value: true} = details_by_key.("testBoolKey")

      assert %{key: "testStringKey", value: "testValue", variation_id: "id"} =
               details_by_key.("testStringKey")

      assert %{key: "testIntKey", value: 1} = details_by_key.("testIntKey")
      assert %{key: "testDoubleKey", value: 1.1} = details_by_key.("testDoubleKey")
      assert %{key: "key1", value: true, variation_id: "fakeId1"} = details_by_key.("key1")
      assert %{key: "key2", value: false, variation_id: "fakeId2"} = details_by_key.("key2")
    end

    test "reports error for incorrect config json", %{client: client, fetch_time_ms: fetch_time_ms} do
      config =
        Config.inline_salt_and_segments(~J"""
         {
           "f": {
             "testKey":  {
               "t": 0,
               "r": [ {
                 "c": [ { "u": { "a": "Custom1", "c": 19, "d": "wrong_utc_timestamp" } } ],
                 "s": { "v": { "b": true } }
               } ],
               "v": { "b": false }
             }
           }
        }
        """)

      stub_cached_config({:ok, config, fetch_time_ms})
      user = User.new("1234", custom: %{"Custom1" => 1_681_118_000.56})
      test_pid = self()

      [client: client]
      |> ConfigCat.hooks()
      |> Hooks.add_on_error(fn error -> send(test_pid, {:on_error, error}) end)

      refute ConfigCat.get_value("testKey", false, user, client: client)
      assert_received {:on_error, error}
      assert error =~ "Failed to evaluate setting 'testKey'."
    end

    for {key, user_id, default_value, expected_value, warning?} <- [
          # no type mismatch warning
          {"testStringKey", "test@example.com", "default", "testValue", false},
          {"testBoolKey", nil, false, true, false},
          {"testBoolKey", nil, nil, true, false},
          {"testIntKey", nil, 3.14, 1, false},
          {"testIntKey", nil, 42, 1, false},
          {"testDoubleKey", nil, 3.14, 1.1, false},
          {"testDoubleKey", nil, 42, 1.1, false},
          # type mismatch warning
          {"testStringKey", "test@example.com", 0, "testValue", true},
          {"testStringKey", "test@example.com", false, "testValue", true},
          {"testBoolKey", nil, 0, true, true},
          {"testBoolKey", nil, 0.1, true, true},
          {"testBoolKey", nil, "default", true, true}
        ] do
      test "default value and setting type mismatch with key: #{key} user_id: #{user_id} default_value: #{default_value}",
           %{client: client} do
        key = unquote(key)
        user_id = unquote(user_id)
        default_value = unquote(default_value)
        expected_value = unquote(expected_value)
        warning? = unquote(warning?)
        user = if user_id, do: User.new(user_id)

        logs =
          capture_log(fn ->
            assert expected_value == ConfigCat.get_value(key, default_value, user, client: client)
          end)

        if warning? do
          default_type = SettingType.infer_elixir_type(default_value)
          expected_type = SettingType.infer_elixir_type(expected_value)

          expected_log =
            adjust_log_level(
              "warning [4002] The type of a setting does not match the type of the specified default value (#{default_value}). " <>
                "Setting's type was #{expected_type} but the default value's type was #{default_type}. " <>
                "Please make sure that using a default value not matching the setting's type was intended."
            )

          assert expected_log in String.split(logs, "\n")
        else
          assert logs == ""
        end
      end
    end
  end

  describe "when the configuration has not been fetched" do
    setup do
      {:ok, client} = start_client()

      stub_cached_config({:error, :not_found})

      {:ok, client: client}
    end

    test "get_all_keys/1 returns an empty list of keys", %{client: client} do
      assert ConfigCat.get_all_keys(client: client) == []
    end

    test "get_value/4 returns default value", %{client: client} do
      assert ConfigCat.get_value("any_feature", "default", client: client) == "default"
    end

    test "get_key_and_value/2 returns nil", %{client: client} do
      assert ConfigCat.get_key_and_value("any_variation", client: client) == nil
    end

    test "get_all_values/1 returns an empty map", %{client: client} do
      assert ConfigCat.get_all_values(nil, client: client) == %{}
    end
  end
end
