defmodule ConfigCat.ConfigTest do
  use ExUnit.Case, async: true

  alias ConfigCat.Config
  alias ConfigCat.Config.Preferences

  describe "merging configs" do
    test "copies right settings when left settings are missing" do
      settings = %{"right" => "settings"}
      left = Config.new()
      right = Config.new(settings: settings)
      merged = Config.merge(left, right)

      assert Config.settings(merged) == settings
    end

    test "keeps left settings when right settings are missing" do
      settings = %{"left" => "settings"}
      left = Config.new(settings: settings)
      right = Config.new()
      merged = Config.merge(left, right)

      assert Config.settings(merged) == settings
    end

    test "merges settings when both are present; right wins when both have the same key" do
      left = Config.new(settings: %{"a" => "left_a", "b" => "left_b"})
      right = Config.new(settings: %{"b" => "right_b", "c" => "right_c"})
      merged = Config.merge(left, right)

      assert %{
               "a" => "left_a",
               "b" => "right_b",
               "c" => "right_c"
             } == Config.settings(merged)
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
