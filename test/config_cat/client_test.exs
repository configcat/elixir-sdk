defmodule ConfigCat.ClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.{Client, MockCachePolicy}

  @cache_policy_id :cache_policy_id

  setup :verify_on_exit!

  setup do
    config = Jason.decode!(~s(
      {
        "p": {"u": "https://cdn-global.configcat.com", "r": 0},
        "f": {
          "testBoolKey": {"v": true,"t": 0, "p": [],"r": []},
          "testStringKey": {"v": "testValue","t": 1, "p": [],"r": []},
          "testIntKey": {"v": 1,"t": 2, "p": [],"r": []},
          "testDoubleKey": {"v": 1.1,"t": 3,"p": [],"r": []},
          "key1": {"v": true, "i": "fakeId1","p": [], "r": []},
          "key2": {"v": false, "i": "fakeId2","p": [], "r": []}
        }
      }
    ))

    {:ok, config: config}
  end

  describe "when the configuration has been fetched" do
    setup %{config: config} do
      {:ok, client} = start_client()

      MockCachePolicy
      |> stub(:get, fn @cache_policy_id -> {:ok, config} end)

      {:ok, client: client}
    end

    test "get_all_keys/1 returns all known keys", %{client: client} do
      expected = ~w(testBoolKey testStringKey testIntKey testDoubleKey key1 key2) |> Enum.sort()
      actual = client |> Client.get_all_keys() |> Enum.sort()
      assert actual == expected
    end

    test "get_value/4 returns a boolean value", %{client: client} do
      assert Client.get_value(client, "testBoolKey", false) == true
    end

    test "get_value/4 returns a string value", %{client: client} do
      assert Client.get_value(client, "testStringKey", "default") == "testValue"
    end

    test "get_value/4 returns an integer value", %{client: client} do
      assert Client.get_value(client, "testIntKey", 0) == 1
    end

    test "get_value/4 returns a double value", %{client: client} do
      assert Client.get_value(client, "testDoubleKey", 0.0) == 1.1
    end

    @tag capture_log: true
    test "get_value/4 returns default value if key not found", %{client: client} do
      assert Client.get_value(client, "testUnknownKey", "default") == "default"
    end

    test "get_variation_id/4 looks up the variation id for a key", %{client: client} do
      assert Client.get_variation_id(client, "key1", nil) == "fakeId1"
      assert Client.get_variation_id(client, "key2", nil) == "fakeId2"
    end

    @tag capture_log: true
    test "get_variation_id/4 returns default if variation id not found", %{client: client} do
      assert Client.get_variation_id(client, "nonexisting", "default_variation_id") ==
               "default_variation_id"
    end

    test "get_all_variation_ids/1 returns all known variation ids", %{client: client} do
      expected = ~w(fakeId1 fakeId2) |> Enum.sort()
      actual = client |> Client.get_all_variation_ids() |> Enum.sort()
      assert actual == expected
    end

    test "get_key_and_value/2 returns matching key/value pair for a variation id", %{
      client: client
    } do
      assert {"key1", true} = Client.get_key_and_value(client, "fakeId1")
      assert {"key2", false} = Client.get_key_and_value(client, "fakeId2")
    end

    test "get_all_values/1 returns all key/value pairs", %{client: client} do
      expected = %{
        "testBoolKey" => true,
        "testStringKey" => "testValue",
        "testIntKey" => 1,
        "testDoubleKey" => 1.1,
        "key1" => true,
        "key2" => false
      } |> Enum.sort()
      actual = client |> Client.get_all_values() |> Enum.sort()
      assert actual == expected
    end
  end

  describe "when the configuration has not been fetched" do
    setup do
      {:ok, client} = start_client()

      MockCachePolicy
      |> stub(:get, fn @cache_policy_id -> {:error, :not_found} end)

      {:ok, client: client}
    end

    test "get_all_keys/1 returns an empty list of keys", %{client: client} do
      assert Client.get_all_keys(client) == []
    end

    test "get_value/4 returns default value", %{client: client} do
      assert Client.get_value(client, "any_feature", "default") == "default"
    end

    test "get_variation_id/4 returns default variation", %{client: client} do
      assert Client.get_variation_id(client, "any_feature", "default") == "default"
    end

    test "get_all_variation_ids/2 returns an empty list of variation ids", %{client: client} do
      assert Client.get_all_variation_ids(client) == []
    end

    @tag capture_log: true
    test "get_key_and_value/2 returns nil", %{client: client} do
      assert Client.get_key_and_value(client, "any_variation") == nil
    end
  end

  defp start_client do
    name = UUID.uuid4() |> String.to_atom()

    options = [
      cache_policy: MockCachePolicy,
      cache_policy_id: @cache_policy_id,
      name: name
    ]

    {:ok, _pid} = Client.start_link(options)

    allow(MockCachePolicy, self(), name)

    {:ok, name}
  end
end
