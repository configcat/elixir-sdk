defmodule ConfigCat.ConfigEntryTest do
  use ExUnit.Case, async: true

  alias ConfigCat.ConfigEntry

  @config_json """
  {
    "p": {
      "u": "https://cdn-global.configcat.com",
      "r": 0
    },
    "f": {
      "testKey": { "v": "testValue", "t": 1, "p": [], "r": []}
    }
  }
  """
  @config Jason.decode!(@config_json)

  describe "serialization" do
    test "serializes to a string" do
      now_seconds = 1_686_756_435.8449
      etag = "test-etag"

      entry = %ConfigEntry{
        config: @config,
        etag: etag,
        fetch_time: now_seconds,
        raw_config: @config_json
      }

      assert ConfigEntry.serialize(entry) == "1686756435844\n#{etag}\n#{@config_json}"
    end

    test "deserializes from a string" do
      str = "1686756435844\ntest-etag\n" <> @config_json

      assert {:ok,
              %ConfigEntry{
                config: @config,
                etag: "test-etag",
                fetch_time: 1_686_756_435.844,
                raw_config: @config_json
              }} = ConfigEntry.deserialize(str)
    end

    test "fails to deserialize an empty string" do
      assert {:error, message} = ConfigEntry.deserialize("")
      assert message =~ ~r/fewer/
    end

    test "fails to deserialize an incorrectly-formatted string" do
      assert {:error, message} = ConfigEntry.deserialize("1234567890\nETAG")
      assert message =~ ~r/fewer/
    end

    test "fails to deserialize an invalid fetch time" do
      assert {:error, message} = ConfigEntry.deserialize("not-a-number\nETAG\n#{@config_json}")
      assert message =~ ~r/Invalid fetch time/
    end

    test "fails to deserialize with an empty etag" do
      assert {:error, message} = ConfigEntry.deserialize("1234567890\n\n#{@config_json}")
      assert message =~ ~r/Empty eTag value/
    end

    test "fails to deserialize invalid JSON" do
      assert {:error, message} = ConfigEntry.deserialize("1234567890\nETAG\ninvalid-json")
      assert message =~ ~r/Invalid config JSON/
    end
  end
end
