defmodule ConfigCat.UserTest do
  use ExUnit.Case, async: true

  alias ConfigCat.User

  describe "creating a user" do
    test "creates a user with only an identifier" do
      identifier = "IDENTIFIER"
      user = User.new(identifier)

      assert %User{identifier: ^identifier, email: nil, country: nil, custom: %{}} = user
    end

    test "creates a user without any properties" do
      user = User.new(nil)

      assert %User{identifier: nil, email: nil, country: nil, custom: %{}} = user
    end

    test "creates a user with additional properties" do
      identifier = "IDENTIFIER"
      email = "me@example.com"
      country = "COUNTRY"
      user = User.new(identifier, email: email, country: country)

      assert %User{identifier: ^identifier, email: ^email, country: ^country, custom: %{}} = user
    end

    test "creates a user with custom properties" do
      identifier = "IDENTIFIER"
      custom_property = 42
      user = User.new(identifier, custom: %{custom_property: custom_property})

      assert %User{
               identifier: ^identifier,
               email: nil,
               country: nil,
               custom: %{custom_property: ^custom_property}
             } = user
    end
  end

  describe "looking up attributes" do
    setup do
      user =
        User.new("IDENTIFIER",
          email: "EMAIL",
          country: "COUNTRY",
          custom: %{
            :atom_property => "ATOM_VALUE",
            "string_property" => "STRING_VALUE",
            "UpperStringProperty" => "UPPER_STRING_VALUE"
          }
        )

      {:ok, user: user}
    end

    test "looks up identifier", %{user: user} do
      value = User.get_attribute(user, "Identifier")
      assert value == user.identifier
    end

    test "looks up email", %{user: user} do
      value = User.get_attribute(user, "Email")
      assert value == user.email
    end

    test "looks up country", %{user: user} do
      value = User.get_attribute(user, "Country")
      assert value == user.country
    end

    test "looks up a custom property with an atom key", %{user: user} do
      value = User.get_attribute(user, "atom_property")
      assert value == user.custom[:atom_property]
    end

    test "looks up a custom property with a string key", %{user: user} do
      value = User.get_attribute(user, "string_property")
      assert value == user.custom["string_property"]
    end

    test "returns nil for null attributes" do
      user = User.new("IDENTIFIER")

      assert User.get_attribute(user, "Email") == nil
      assert User.get_attribute(user, "Country") == nil
      assert User.get_attribute(user, "AnyCustom") == nil
    end

    test "attribute names are case-sensitive", %{user: user} do
      assert User.get_attribute(user, "identifier") == nil
      assert User.get_attribute(user, "EMAIL") == nil
      assert User.get_attribute(user, "country") == nil
      assert User.get_attribute(user, "UPPERSTRINGPROPERTY") == nil
    end
  end

  describe "converting to string" do
    test "produces a JSON-encoded string" do
      user_id = "id"
      email = "test@test.com"
      country = "country"

      custom = %{
        "datetime" => ~U[2023-09-19T11:01:35.999Z],
        "float" => 3.14,
        "int" => 42,
        "string" => "test"
      }

      user = User.new(user_id, country: country, custom: custom, email: email)

      assert %{
               "Identifier" => user_id,
               "Email" => email,
               "Country" => country,
               "string" => "test",
               "int" => 42,
               "float" => 3.14,
               "datetime" => "2023-09-19T11:01:35.999Z"
             } == Jason.decode!(to_string(user))
    end
  end
end
