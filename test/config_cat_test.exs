defmodule ConfigCatTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.Client
  alias ConfigCat.MockCachePolicy
  alias ConfigCat.NullDataSource

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
      actual = ConfigCat.get_all_keys(client: client) |> Enum.sort()
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

    test "get_all_variation_ids/1 returns all known variation ids", %{client: client} do
      expected = ~w(fakeId1 fakeId2) |> Enum.sort()
      actual = ConfigCat.get_all_variation_ids(client: client) |> Enum.sort()
      assert actual == expected
    end

    test "get_key_and_value/2 returns matching key/value pair for a variation id", %{
      client: client
    } do
      assert {"key1", true} = ConfigCat.get_key_and_value("fakeId1", client: client)
      assert {"key2", false} = ConfigCat.get_key_and_value("fakeId2", client: client)
    end

    test "get_all_values/1 returns all key/value pairs", %{client: client} do
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
  end

  describe "when the configuration has not been fetched" do
    setup do
      {:ok, client} = start_client()

      MockCachePolicy
      |> stub(:get, fn @cache_policy_id -> {:error, :not_found} end)

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

  defp start_client do
    base_name = UUID.uuid4() |> String.to_atom()
    name = ConfigCat.Supervisor.client_name(base_name)

    options = [
      cache_policy: MockCachePolicy,
      cache_policy_id: @cache_policy_id,
      flag_overrides: NullDataSource.new(),
      name: name
    ]

    {:ok, _pid} = start_supervised({Client, options})

    allow(MockCachePolicy, self(), name)

    {:ok, base_name}
  end
end