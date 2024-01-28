defmodule ConfigCat.SpecialCharactersTest do
  # Must be async: false to avoid a collision with other tests.
  # Now that we only allow a single ConfigCat instance to use the same SDK key,
  # one of the async tests would fail due to the existing running instance.
  use ConfigCat.Case, async: false

  alias ConfigCat.User

  @sdk_key "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/u28_1qNyZ0Wz-ldYHIU7-g"
  @user User.new("äöüÄÖÜçéèñışğâ¢™✓😀")

  test "special characters work in cleartext" do
    {:ok, client} = start_config_cat(@sdk_key)

    assert "äöüÄÖÜçéèñışğâ¢™✓😀" == ConfigCat.get_value("specialCharacters", "NOT_CAT", @user, client: client)
  end

  test "special characters work when hashed" do
    {:ok, client} = start_config_cat(@sdk_key)

    assert "äöüÄÖÜçéèñışğâ¢™✓😀" == ConfigCat.get_value("specialCharactersHashed", "NOT_CAT", @user, client: client)
  end
end
