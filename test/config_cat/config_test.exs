defmodule ConfigCat.ConfigTest do
  use ExUnit.Case, async: true

  alias ConfigCat.Config
  alias ConfigCat.Config.Preferences

  describe "merging configs" do
    test "copies right flags when left flags are missing" do
      flags = %{"right" => "flags"}
      left = Config.new()
      right = Config.new(feature_flags: flags)
      merged = Config.merge(left, right)

      assert Config.feature_flags(merged) == flags
    end

    test "keeps left flags when right flags are missing" do
      flags = %{"left" => "flags"}
      left = Config.new(feature_flags: flags)
      right = Config.new()
      merged = Config.merge(left, right)

      assert Config.feature_flags(merged) == flags
    end

    test "merges flags when both are present; right wins when both have the same flag" do
      left = Config.new(feature_flags: %{"a" => "left_a", "b" => "left_b"})
      right = Config.new(feature_flags: %{"b" => "right_b", "c" => "right_c"})
      merged = Config.merge(left, right)

      assert %{
               "a" => "left_a",
               "b" => "right_b",
               "c" => "right_c"
             } == Config.feature_flags(merged)
    end

    test "always keeps left preferences" do
      left_preferences = Preferences.new(base_url: "https://left.example.com")
      right_preferences = Preferences.new(base_url: "https://right.example.com")
      left = Config.new(preferences: left_preferences)
      right = Config.new(preferences: right_preferences)
      merged = Config.merge(left, right)

      assert Config.preferences(merged) == left_preferences
    end
  end
end
