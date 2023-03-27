defmodule ConfigCat.DefaultUserTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.{Client, MockCachePolicy, NullDataSource, User}

  @moduletag capture_log: true

  @cache_policy_id :cache_policy_id

  setup do
    config = Jason.decode!(~s(
      {
        "p": {"u": "https://cdn-global.configcat.com", "r": 0},
        "f": {
          "testBoolKey": {"v": true,"t": 0, "p": [],"r": []},
          "testStringKey": {
            "v": "testValue", "i": "id", "t": 1, "p": [], "r": [
              {"i":"id1","v":"fake1","a":"Identifier","t":2,"c":"@test1.com"},
              {"i":"id2","v":"fake2","a":"Identifier","t":2,"c":"@test2.com"}
            ]
          }
        }
      }
    ))

    MockCachePolicy
    |> stub(:get, fn @cache_policy_id -> {:ok, config} end)

    {:ok, config: config}
  end

  describe "when the default user is defined in the options" do
    setup do
      {:ok, client} = start_client(User.new("test@test1.com"))
      {:ok, client: client}
    end

    test "get_value/4 uses the default user if no user is passed", %{client: client} do
      assert Client.get_value(client, "testStringKey", "") == "fake1"
    end

    test "get_value/4 uses the passed user", %{client: client} do
      user = User.new("test@test2.com")
      assert Client.get_value(client, "testStringKey", "", user) == "fake2"
    end

    test "get_value/4 uses the undefined user case if default user is cleared", %{client: client} do
      Client.clear_default_user(client)
      assert Client.get_value(client, "testStringKey", "") == "testValue"
    end

    test "get_all_values/1 uses the default user if no user is passed", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "fake1"
        }
        |> Enum.sort()

      actual = client |> Client.get_all_values() |> Enum.sort()
      assert actual == expected
    end

    test "get_all_values/1 uses the passed user", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "fake2"
        }
        |> Enum.sort()

      user = User.new("test@test2.com")
      actual = client |> Client.get_all_values(user) |> Enum.sort()
      assert actual == expected
    end
  end

  describe "when the default user is not defined in the options" do
    setup do
      {:ok, client} = start_client()
      {:ok, client: client}
    end

    test "get_value/4 uses the undefined user case if no user is passed", %{client: client} do
      assert Client.get_value(client, "testStringKey", "") == "testValue"
    end

    test "get_value/4 uses the passed user", %{client: client} do
      user = User.new("test@test2.com")
      assert Client.get_value(client, "testStringKey", "", user) == "fake2"
    end

    test "get_value/4 uses the default user if no user is passed", %{client: client} do
      Client.set_default_user(client, User.new("test@test1.com"))
      assert Client.get_value(client, "testStringKey", "") == "fake1"
    end

    test "get_all_values/1 uses the undefined user case if no user is passed", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "testValue"
        }
        |> Enum.sort()

      actual = client |> Client.get_all_values() |> Enum.sort()
      assert actual == expected
    end

    test "get_all_values/1 uses the passed user", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "fake2"
        }
        |> Enum.sort()

      user = User.new("test@test2.com")
      actual = client |> Client.get_all_values(user) |> Enum.sort()
      assert actual == expected
    end
  end

  defp start_client(default_user \\ nil) do
    name = UUID.uuid4() |> String.to_atom()

    options = [
      cache_policy: MockCachePolicy,
      cache_policy_id: @cache_policy_id,
      default_user: default_user,
      flag_overrides: NullDataSource.new(),
      name: name
    ]

    {:ok, _pid} = start_supervised({Client, options})

    allow(MockCachePolicy, self(), name)

    {:ok, name}
  end
end
