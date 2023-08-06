defmodule ConfigCatTest do
  use ConfigCat.ClientCase, async: true

  import Jason.Sigil
  import Mox

  alias ConfigCat.ConfigEntry
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.User

  require ConfigCat.Constants, as: Constants

  setup :verify_on_exit!

  describe "when the configuration has been fetched" do
    setup do
      settings = ~J"""
        {
          "testBoolKey": {"v": true,"t": 0, "p": [],"r": []},
          "testStringKey": {"v": "testValue", "i": "id", "t": 1, "p": [],"r": [
            {"i":"id1","v":"fake1","a":"Identifier","t":2,"c":"@test1.com"},
            {"i":"id2","v":"fake2","a":"Identifier","t":2,"c":"@test2.com"}
          ]},
          "testIntKey": {"v": 1,"t": 2, "p": [],"r": []},
          "testDoubleKey": {"v": 1.1,"t": 3,"p": [],"r": []},
          "key1": {"v": true, "i": "fakeId1","p": [], "r": []},
          "key2": {"v": false, "i": "fakeId2","p": [], "r": []}
        }
      """

      {:ok, client} = start_client()

      fetch_time_ms = ConfigEntry.now()
      stub_cached_settings({:ok, settings, fetch_time_ms})

      {:ok, client: client, fetch_time_ms: fetch_time_ms}
    end

    test "get_all_keys/1 returns all known keys", %{client: client} do
      expected = ~w(testBoolKey testStringKey testIntKey testDoubleKey key1 key2) |> Enum.sort()
      actual = ConfigCat.get_all_keys(client: client) |> Enum.sort()
      assert actual == expected
    end

    test "get_value/4 returns a boolean value", %{client: client} do
      assert ConfigCat.get_value("testBoolKey", false, client: client) == true
    end

    @tag capture_log: true
    test "get_value/4 returns a string value", %{client: client} do
      assert ConfigCat.get_value("testStringKey", "default", client: client) == "testValue"
    end

    test "get_value/4 returns an integer value", %{client: client} do
      assert ConfigCat.get_value("testIntKey", 0, client: client) == 1
    end

    test "get_value/4 returns a double value", %{client: client} do
      assert ConfigCat.get_value("testDoubleKey", 0.0, client: client) == 1.1
    end

    @tag capture_log: true
    test "get_value/4 returns default value if key not found", %{client: client} do
      assert ConfigCat.get_value("testUnknownKey", "default", client: client) == "default"
    end

    test "get_variation_id/4 looks up the variation id for a key", %{client: client} do
      assert ConfigCat.get_variation_id("key1", nil, client: client) == "fakeId1"
      assert ConfigCat.get_variation_id("key2", nil, client: client) == "fakeId2"
    end

    @tag capture_log: true
    test "get_variation_id/4 returns default if variation id not found", %{client: client} do
      assert ConfigCat.get_variation_id("nonexisting", "default_variation_id", client: client) ==
               "default_variation_id"
    end

    @tag capture_log: true
    test "get_all_variation_ids/1 returns all known variation ids", %{client: client} do
      expected = ~w(fakeId1 fakeId2 id) |> Enum.sort()
      actual = ConfigCat.get_all_variation_ids(client: client) |> Enum.sort()
      assert actual == expected
    end

    test "get_key_and_value/2 returns matching key/value pair for a variation id", %{
      client: client
    } do
      assert {"key1", true} = ConfigCat.get_key_and_value("fakeId1", client: client)
      assert {"key2", false} = ConfigCat.get_key_and_value("fakeId2", client: client)
    end

    @tag capture_log: true
    test "get_all_values/2 returns all key/value pairs", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "testValue",
          "testIntKey" => 1,
          "testDoubleKey" => 1.1,
          "key1" => true,
          "key2" => false
        }
        |> Enum.sort()

      actual = ConfigCat.get_all_values(nil, client: client) |> Enum.sort()
      assert actual == expected
    end

    test "get_value_details/2 returns evaluation details", %{
      client: client,
      fetch_time_ms: fetch_time_ms
    } do
      user = User.new("test@test1.com")

      fetch_time = DateTime.from_unix!(fetch_time_ms, :millisecond)

      assert %EvaluationDetails{
               default_value?: false,
               error: nil,
               fetch_time: ^fetch_time,
               key: "testStringKey",
               matched_evaluation_rule: %{
                 Constants.comparator() => 2,
                 Constants.comparison_attribute() => "Identifier",
                 Constants.comparison_value() => "@test1.com",
                 Constants.value() => "fake1"
               },
               matched_evaluation_percentage_rule: nil,
               user: ^user,
               value: "fake1",
               variation_id: "id1"
             } = ConfigCat.get_value_details("testStringKey", "", user, client: client)
    end
  end

  describe "when the configuration has not been fetched" do
    setup do
      {:ok, client} = start_client()

      stub_cached_settings({:error, :not_found})

      {:ok, client: client}
    end

    test "get_all_keys/1 returns an empty list of keys", %{client: client} do
      assert ConfigCat.get_all_keys(client: client) == []
    end

    test "get_value/4 returns default value", %{client: client} do
      assert ConfigCat.get_value("any_feature", "default", client: client) == "default"
    end

    test "get_variation_id/4 returns default variation", %{client: client} do
      assert ConfigCat.get_variation_id("any_feature", "default", client: client) == "default"
    end

    test "get_all_variation_ids/2 returns an empty list of variation ids", %{client: client} do
      assert ConfigCat.get_all_variation_ids(client: client) == []
    end

    @tag capture_log: true
    test "get_key_and_value/2 returns nil", %{client: client} do
      assert ConfigCat.get_key_and_value("any_variation", client: client) == nil
    end

    test "get_all_values/1 returns an empty map", %{client: client} do
      assert ConfigCat.get_all_values(nil, client: client) == %{}
    end
  end
end
