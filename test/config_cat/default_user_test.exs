defmodule ConfigCat.DefaultUserTest do
  use ConfigCat.ClientCase, async: true

  import Jason.Sigil

  alias ConfigCat.FetchTime
  alias ConfigCat.User

  @moduletag capture_log: true

  setup do
    settings = ~J"""
      {
        "testBoolKey": {"v": true,"t": 0, "p": [],"r": []},
        "testStringKey": {
          "v": "testValue", "i": "id", "t": 1, "p": [], "r": [
            {"i":"id1","v":"fake1","a":"Identifier","t":2,"c":"@test1.com"},
            {"i":"id2","v":"fake2","a":"Identifier","t":2,"c":"@test2.com"}
          ]
        }
      }
    """

    stub_cached_settings({:ok, settings, FetchTime.now_ms()})

    :ok
  end

  describe "when the default user is defined in the options" do
    setup do
      {:ok, client} = start_client(default_user: User.new("test@test1.com"))
      {:ok, client: client}
    end

    test "get_value/4 uses the default user if no user is passed", %{client: client} do
      assert ConfigCat.get_value("testStringKey", "", client: client) == "fake1"
    end

    test "get_value/4 uses the passed user", %{client: client} do
      user = User.new("test@test2.com")
      assert ConfigCat.get_value("testStringKey", "", user, client: client) == "fake2"
    end

    test "get_value/4 uses the undefined user case if default user is cleared", %{client: client} do
      ConfigCat.clear_default_user(client: client)
      assert ConfigCat.get_value("testStringKey", "", client: client) == "testValue"
    end

    test "get_all_values/1 uses the default user if no user is passed", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "fake1"
        }
        |> Enum.sort()

      actual = ConfigCat.get_all_values(nil, client: client) |> Enum.sort()
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
      actual = ConfigCat.get_all_values(user, client: client) |> Enum.sort()
      assert actual == expected
    end
  end

  describe "when the default user is not defined in the options" do
    setup do
      {:ok, client} = start_client()
      {:ok, client: client}
    end

    test "get_value/4 uses the undefined user case if no user is passed", %{client: client} do
      assert ConfigCat.get_value("testStringKey", "", client: client) == "testValue"
    end

    test "get_value/4 uses the passed user", %{client: client} do
      user = User.new("test@test2.com")
      assert ConfigCat.get_value("testStringKey", "", user, client: client) == "fake2"
    end

    test "get_value/4 uses the default user if no user is passed", %{client: client} do
      ConfigCat.set_default_user(User.new("test@test1.com"), client: client)
      assert ConfigCat.get_value("testStringKey", "", client: client) == "fake1"
    end

    test "get_all_values/1 uses the undefined user case if no user is passed", %{client: client} do
      expected =
        %{
          "testBoolKey" => true,
          "testStringKey" => "testValue"
        }
        |> Enum.sort()

      actual = ConfigCat.get_all_values(nil, client: client) |> Enum.sort()
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
      actual = ConfigCat.get_all_values(user, client: client) |> Enum.sort()
      assert actual == expected
    end
  end
end
