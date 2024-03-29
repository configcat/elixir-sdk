defmodule ConfigCat.RolloutTest do
  # Must be async: false to avoid a collision with other tests.
  # Now that we only allow a single ConfigCat instance to use the same SDK key,
  # one of the async tests would fail due to the existing running instance.
  use ConfigCat.Case, async: false

  import ExUnit.CaptureLog
  import Jason.Sigil

  alias ConfigCat.Config
  alias ConfigCat.Config.SettingType
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.LocalFileDataSource
  alias ConfigCat.LocalMapDataSource
  alias ConfigCat.OverrideDataSource
  alias ConfigCat.Rollout
  alias ConfigCat.User

  require ConfigCat.Config.SettingType

  @moduletag capture_log: true

  @value_test_type "value_test"
  @variation_test_type "variation_test"

  describe "matrix tests (config v1)" do
    test "basic operators" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d62463-86ec-8fde-f5b5-1c5c426fc830/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
    end

    test "numeric operators" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d747f0-5986-c2ef-eef3-ec778e32e10a/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix_number.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/uGyK3q9_ckmdxRyI7vjwCw")
    end

    test "segments v1" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d9f207-6883-43e5-868c-cbf677af3fe6/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix_segments_old.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/LcYz135LE0qbcacz2mgXnA")
    end

    test "semantic version operators" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d745f1-f315-7daf-d163-5541d3786e6f/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix_semantic.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/BAr3KgLTP0ObzKnBTo5nhA")
    end

    test "semantic version operators 2" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d77fa1-a796-85f9-df0c-57c448eb9934/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix_semantic_2.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w")
    end

    test "sensitive text operators" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d7b724-9285-f4a7-9fcd-00f64f1e83d5/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix_sensitive.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/qX3TP2dTj06ZpCCT1h_SPA")
    end

    test "variation ID" do
      # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d774b9-3d05-0027-d5f4-3e76c3dba752/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix("testmatrix_variationId.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/nQ5qkhRAUEa6beEyyrVLBA", @variation_test_type)
    end
  end

  describe "matrix tests (config v2)" do
    test "basic rule evaluation" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbc4dc-1927-4d6b-8fb9-b1472564e2d3/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/AG6C1ngVb0CvM07un6JisQ"
      )
    end

    test "semantic version matching" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbc4dc-278c-4f83-8d36-db73ad6e2a3a/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix_semantic.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg"
      )
    end

    test "semantic version comparisons" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbc4dc-2b2b-451e-8359-abdef494c2a2/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix_semantic_2.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/U8nt3zEhDEO5S2ulubCopA"
      )
    end

    test "numeric comparisons" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbc4dc-0fa3-48d0-8de8-9de55b67fb8b/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix_number.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw"
      )
    end

    test "sensitive information comparisons" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbc4dc-2d62-4e1b-884b-6aa237b34764/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix_sensitive.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/-0YmVOUNgEGKkgRF-rU65g"
      )
    end

    test "v6 comparators" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9a6b-4947-84e2-91529248278a/08dbc325-9ebd-4587-8171-88f76a3004cb
      test_matrix(
        "testmatrix_comparators_v6.csv",
        "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ"
      )
    end

    test "segments" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9cfb-486f-8906-72a57c693615/08dbc325-9ebd-4587-8171-88f76a3004cb
      test_matrix(
        "testmatrix_segments.csv",
        "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/h99HYXWWNE2bH8eWyLAVMA"
      )
    end

    test "segments (old)" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbd6ca-a85f-4ed0-888a-2da18def92b5/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix_segments_old.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/y_ZB7o-Xb0Swxth-ZlMSeA"
      )
    end

    test "prerequisite flags" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9b74-45cb-86d0-4d61c25af1aa/08dbc325-9ebd-4587-8171-88f76a3004cb
      test_matrix(
        "testmatrix_prerequisite_flag.csv",
        "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg"
      )
    end

    test "and/or" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9d5e-4988-891c-fd4a45790bd1/08dbc325-9ebd-4587-8171-88f76a3004cb
      test_matrix(
        "testmatrix_and_or.csv",
        "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/ByMO9yZNn02kXcm72lnY1A"
      )
    end

    test "variation id" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08dbc4dc-30c6-4969-8e4c-03f6a8764199/244cf8b0-f604-11e8-b543-f23c917f9d8d
      test_matrix(
        "testmatrix_variationId.csv",
        "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/spQnkRTIPEWVivZkWM84lQ",
        @variation_test_type
      )
    end

    test "unicode support" do
      # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbd63c-9774-49d6-8187-5f2aab7bd606/08dbc325-9ebd-4587-8171-88f76a3004cb
      test_matrix(
        "testmatrix_unicode.csv",
        "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/Da6w8dBbmUeMUBhh0iEeQQ"
      )
    end
  end

  test "invalid user object" do
    user = %{email: "a@configcat.com"}
    {:ok, client} = start_config_cat("PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
    actual = ConfigCat.get_value("stringContainsDogDefaultCat", "Lion", user, client: client)

    assert actual == "Cat"
  end

  # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9e4e-4f59-86b2-5da50924b6ca/08dbc325-9ebd-4587-8171-88f76a3004cb
  for {user_id, email, percentage_base, expected_return_value, expected_matched_targeting_rule,
       expected_matched_percentage_option} <- [
        {nil, nil, nil, "Cat", false, false},
        {"12345", nil, nil, "Cat", false, false},
        {"12345", "a@example.com", nil, "Dog", true, false},
        {"12345", "a@configcat.com", nil, "Cat", false, false},
        {"12345", "a@configcat.com", "", "Frog", true, true},
        {"12345", "a@configcat.com", "US", "Fish", true, true},
        {"12345", "b@configcat.com", nil, "Cat", false, false},
        {"12345", "b@configcat.com", "", "Falcon", false, true},
        {"12345", "b@configcat.com", "US", "Spider", false, true}
      ] do
    test "matched evaluation rule and percentage option with user_id: #{inspect(user_id)} email: #{inspect(email)} percentage_base: #{inspect(percentage_base)}" do
      sdk_key = "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw"
      key = "stringMatchedTargetingRuleAndOrPercentageOption"
      user_id = unquote(user_id)
      email = unquote(email)
      percentage_base = unquote(percentage_base)
      expected_return_value = unquote(expected_return_value)
      expected_matched_targeting_rule = unquote(expected_matched_targeting_rule)
      expected_matched_percentage_option = unquote(expected_matched_percentage_option)

      {:ok, client} = start_config_cat(sdk_key)

      user = User.new(user_id, email: email, custom: %{"PercentageBase" => percentage_base})

      %EvaluationDetails{} = evaluation_details = ConfigCat.get_value_details(key, nil, user, client: client)
      assert evaluation_details.value == expected_return_value
      assert !is_nil(evaluation_details.matched_targeting_rule) == expected_matched_targeting_rule
      assert !is_nil(evaluation_details.matched_percentage_option) == expected_matched_percentage_option
    end
  end

  test "user object attribute value conversion text comparison" do
    sdk_key = "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ"

    {:ok, client} = start_config_cat(sdk_key)
    custom_attribute_name = "Custom1"
    custom_attribute_value = 42
    user = User.new("12345", custom: %{custom_attribute_name => custom_attribute_value})

    key = "boolTextEqualsNumber"

    logs =
      capture_log(fn ->
        assert ConfigCat.get_value(key, nil, user, client: client)
      end)

    expected_log =
      adjust_log_level(
        "warning [3005] Evaluation of condition (User.#{custom_attribute_name} EQUALS '#{custom_attribute_value}') " <>
          "for setting '#{key}' may not produce the expected result (the User.#{custom_attribute_name} attribute is not a string value, " <>
          "thus it was automatically converted to the string value '#{custom_attribute_value}'). " <>
          "Please make sure that using a non-string value was intended."
      )

    assert expected_log in String.split(logs, "\n", trim: true)
  end

  test "config json type mismatch" do
    config =
      Config.inline_salt_and_segments(~j"""
      {
          "f": {
              "test": {
                  "t": #{SettingType.string()},
                  "v": {"b": true}
              }
          }
      }
      """)

    logs =
      capture_log(fn ->
        assert %EvaluationDetails{value: false} = Rollout.evaluate("test", nil, false, "default_variation_id", config)
      end)

    expected_log =
      "error [2001] Failed to evaluate setting 'test'. " <>
        "(Setting value is not of the expected type String.t())"

    assert logs =~ expected_log
  end

  for {sdk_key, key, custom_attribute_value, expected_return_value} <- [
        # SemVer-based comparisons
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "0.0", "20%"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "0.9.9", "< 1.0.0"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "1.0.0", "20%"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "1.1", "20%"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", 0, "20%"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", 0.9, "20%"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", 2, "20%"},
        # Number-based comparisons
        # {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", float(~c"-inf"),
        #  "<2.1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", -1, "<2.1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", 2, "<2.1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", 2.1, "<=2,1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", 3, "<>4.2"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", 5, ">=5"},
        # {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", float('inf'), ">5"},
        # {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
        # "numberWithPercentage", float('nan'), "<>4.2"},
        # {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "-inf", "<2.1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "-1", "<2.1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "2", "<2.1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "2.1", "<=2,1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "2,1", "<=2,1"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "3", "<>4.2"},
        {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "5", ">=5"},
        # {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "inf", ">5"},
        # {"configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "nan", "<>4.2"},
        # Date time-based comparisons
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         ~N[2023-03-31T23:59:59.999000], false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         ~U[2023-03-31T23:59:59.999000Z], false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         DateTime.new!(~D[2023-04-01], ~T[01:59:59.999000], "Etc/GMT-2"), false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         ~U[2023-04-01T00:00:00.001000Z], true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         DateTime.new!(~D[2023-04-01], ~T[02:00:00.001000], "Etc/GMT-2"), true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         ~U[2023-04-30T23:59:59.999000Z], true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         DateTime.new!(~D[2023-05-01], ~T[01:59:59.999000], "Etc/GMT-2"), true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         ~U[2023-05-01T00:00:00.001000Z], false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304",
         DateTime.new!(~D[2023-05-01], ~T[02:00:00.001000], "Etc/GMT-2"), false},
        # {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", float('-inf'), false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_680_307_199.999, false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_680_307_200.001, true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_682_899_199.999, true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_682_899_200.001, false},
        # {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", float('inf'), false},
        # {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", float("nan"), false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_680_307_199, false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_680_307_201, true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_682_899_199, true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", 1_682_899_201, false},
        # {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "-inf", false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "1680307199.999", false},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "1680307200.001", true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "1682899199.999", true},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "1682899200.001", false},
        # {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "+inf", false},
        # {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "NaN", false},
        # String array-based comparisons
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat",
         ["x", "read"], "Dog"},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat",
         ["x", "Read"], "Cat"},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat",
         "[\"x\", \"read\"]", "Dog"},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat",
         "[\"x\", \"Read\"]", "Cat"},
        {"configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat",
         "x, read", "Cat"}
      ] do
    test "attribute value conversion with key: '#{key}' value: '#{inspect(custom_attribute_value)}" do
      sdk_key = unquote(sdk_key)
      key = unquote(key)
      user_id = "12345"
      custom_attribute_name = "Custom1"
      custom_attribute_value = unquote(Macro.escape(custom_attribute_value))
      expected_return_value = unquote(expected_return_value)

      {:ok, client} = start_config_cat(sdk_key)

      user = User.new(user_id, custom: %{custom_attribute_name => custom_attribute_value})
      actual = ConfigCat.get_value(key, nil, user, client: client)

      assert expected_return_value == actual
    end
  end

  for {key, dependency_cycle} <- [
        {"key1", "'key1' -> 'key1'"},
        {"key2", "'key2' -> 'key3' -> 'key2'"},
        {"key4", "'key4' -> 'key3' -> 'key2' -> 'key3'"}
      ] do
    test "prerequisite flag circular dependency for key: #{key}" do
      key = unquote(key)
      dependency_cycle = unquote(dependency_cycle)

      config =
        "test_circulardependency_v6.json"
        |> fixture_file()
        |> LocalFileDataSource.new(:local_only)
        |> OverrideDataSource.overrides()

      logs =
        capture_log(fn ->
          assert %EvaluationDetails{value: "default_value"} =
                   Rollout.evaluate(key, nil, "default_value", "default_variation_id", config)
        end)

      assert logs =~ "Circular dependency detected"
      assert logs =~ dependency_cycle
    end
  end

  for {key, comparison_value_type, prerequisite_flag_key, prerequisite_flag_value, expected_value} <- [
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", true, "Dog"},
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", false, "Cat"},
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", "1", nil},
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", 1, nil},
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", 1.0, nil},
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", [true], nil},
        {"stringDependsOnBool", "boolean()", "mainBoolFlag", nil, nil},
        {"stringDependsOnString", "String.t()", "mainStringFlag", "private", "Dog"},
        {"stringDependsOnString", "String.t()", "mainStringFlag", "Private", "Cat"},
        {"stringDependsOnString", "String.t()", "mainStringFlag", true, nil},
        {"stringDependsOnString", "String.t()", "mainStringFlag", 1, nil},
        {"stringDependsOnString", "String.t()", "mainStringFlag", 1.0, nil},
        {"stringDependsOnString", "String.t()", "mainStringFlag", ["private"], nil},
        {"stringDependsOnString", "String.t()", "mainStringFlag", nil, nil},
        {"stringDependsOnInt", "integer()", "mainIntFlag", 2, "Dog"},
        {"stringDependsOnInt", "integer()", "mainIntFlag", 1, "Cat"},
        {"stringDependsOnInt", "integer()", "mainIntFlag", "2", nil},
        {"stringDependsOnInt", "integer()", "mainIntFlag", true, nil},
        {"stringDependsOnInt", "integer()", "mainIntFlag", 2.0, nil},
        {"stringDependsOnInt", "integer()", "mainIntFlag", [2], nil},
        {"stringDependsOnInt", "integer()", "mainIntFlag", nil, nil},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", 0.1, "Dog"},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", 0.11, "Cat"},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", "0.1", nil},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", true, nil},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", 1, nil},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", [0.1], nil},
        {"stringDependsOnDouble", "float()", "mainDoubleFlag", nil, nil}
      ] do
    test "prerequisite flag value type mismatch with key: #{key} type: #{comparison_value_type} flag_key: #{prerequisite_flag_key} value: #{inspect(prerequisite_flag_value)}" do
      sdk_key = "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg"
      key = unquote(key)
      flag_key = unquote(prerequisite_flag_key)
      flag_value = unquote(prerequisite_flag_value)
      expected_value = unquote(expected_value)

      flag_overrides = LocalMapDataSource.new(%{flag_key => flag_value}, :local_over_remote)

      {:ok, client} = start_config_cat(sdk_key, flag_overrides: flag_overrides)

      logs =
        capture_log(fn ->
          assert expected_value == ConfigCat.get_value(key, nil, client: client)
        end)

      unless expected_value do
        expected_message =
          ~r/Type mismatch between comparison value '[^']+' and prerequisite flag '#{flag_key}'/

        assert logs =~ expected_message
      end
    end
  end

  for {key, custom_attribute_value, expected_return_value} <- [
        {"numberToStringConversion", 0.12345, "1"},
        {"numberToStringConversionInt", 125.0, "4"},
        {"numberToStringConversionPositiveExp", -1.23456789e96, "2"},
        {"numberToStringConversionNegativeExp", -12345.6789e-100, "4"},
        # {"numberToStringConversionNaN", NaN, "3"},
        # {"numberToStringConversionPositiveInf", Infinity, "4"},
        # {"numberToStringConversionNegativeInf", -Infinity, "3"},
        {"dateToStringConversion", ~U[2023-03-31T23:59:59.9990000Z], "3"},
        {"dateToStringConversion", 1_680_307_199.999, "3"},
        # {"dateToStringConversionNaN", NaN, "3"},
        # {"dateToStringConversionPositiveInf", Infinity, "1"},
        # {"dateToStringConversionNegativeInf", -Infinity, "5"},
        {"stringArrayToStringConversion", ["read", "Write", " eXecute "], "4"},
        {"stringArrayToStringConversionEmpty", [], "5"},
        {"stringArrayToStringConversionSpecialChars", ["+<>%\"'\\/\t\r\n"], "3"},
        {"stringArrayToStringConversionUnicode", ["äöüÄÖÜçéèñışğâ¢™✓😀"], "2"}
      ] do
    test "comparison attribute conversion to canonical string representation - key: #{key} | custom_attribute_value: #{custom_attribute_value}" do
      key = unquote(key)
      custom_attribute_value = unquote(Macro.escape(custom_attribute_value))
      expected_return_value = unquote(expected_return_value)

      config =
        "comparison_attribute_conversion.json"
        |> fixture_file()
        |> LocalFileDataSource.new(:local_only)
        |> OverrideDataSource.overrides()

      user =
        User.new("12345", custom: %{"Custom1" => custom_attribute_value})

      assert %EvaluationDetails{value: ^expected_return_value} = Rollout.evaluate(key, user, "default", nil, config)
    end
  end

  for {key, expected_return_value} <- [
        {"isoneof", "no trim"},
        {"isnotoneof", "no trim"},
        {"isoneofhashed", "no trim"},
        {"isnotoneofhashed", "no trim"},
        {"equalshashed", "no trim"},
        {"notequalshashed", "no trim"},
        {"arraycontainsanyofhashed", "no trim"},
        {"arraynotcontainsanyofhashed", "no trim"},
        {"equals", "no trim"},
        {"notequals", "no trim"},
        {"startwithanyof", "no trim"},
        {"notstartwithanyof", "no trim"},
        {"endswithanyof", "no trim"},
        {"notendswithanyof", "no trim"},
        {"arraycontainsanyof", "no trim"},
        {"arraynotcontainsanyof", "no trim"},
        {"startwithanyofhashed", "no trim"},
        {"notstartwithanyofhashed", "no trim"},
        {"endswithanyofhashed", "no trim"},
        {"notendswithanyofhashed", "no trim"},
        # semver comparators user values trimmed because of backward compatibility
        {"semverisoneof", "4 trim"},
        {"semverisnotoneof", "5 trim"},
        {"semverless", "6 trim"},
        {"semverlessequals", "7 trim"},
        {"semvergreater", "8 trim"},
        {"semvergreaterequals", "9 trim"},
        # number and date comparators user values trimmed because of backward compatibility
        {"numberequals", "10 trim"},
        {"numbernotequals", "11 trim"},
        {"numberless", "12 trim"},
        {"numberlessequals", "13 trim"},
        {"numbergreater", "14 trim"},
        {"numbergreaterequals", "15 trim"},
        {"datebefore", "18 trim"},
        {"dateafter", "19 trim"},
        # "contains any of" and "not contains any of" is a special case,
        # the not trimmed user attribute checked against not trimmed comparator values.
        {"containsanyof", "no trim"},
        {"notcontainsanyof", "no trim"}
      ] do
    test "comparison attribute trimming - key: #{key}" do
      key = unquote(key)
      expected_return_value = unquote(expected_return_value)

      config =
        "comparison_attribute_trimming.json"
        |> fixture_file()
        |> LocalFileDataSource.new(:local_only)
        |> OverrideDataSource.overrides()

      user =
        User.new(" 12345 ",
          country: ~s([" USA "]),
          custom: %{
            "Version" => " 1.0.0 ",
            "Number" => " 3 ",
            "Date" => " 1705253400 "
          }
        )

      assert %EvaluationDetails{value: ^expected_return_value} = Rollout.evaluate(key, user, "default", nil, config)
    end
  end

  for {key, expected_return_value} <- [
        {"isoneof", "no trim"},
        {"isnotoneof", "no trim"},
        {"containsanyof", "no trim"},
        {"notcontainsanyof", "no trim"},
        {"isoneofhashed", "no trim"},
        {"isnotoneofhashed", "no trim"},
        {"equalshashed", "no trim"},
        {"notequalshashed", "no trim"},
        {"arraycontainsanyofhashed", "no trim"},
        {"arraynotcontainsanyofhashed", "no trim"},
        {"equals", "no trim"},
        {"notequals", "no trim"},
        {"startwithanyof", "no trim"},
        {"notstartwithanyof", "no trim"},
        {"endswithanyof", "no trim"},
        {"notendswithanyof", "no trim"},
        {"arraycontainsanyof", "no trim"},
        {"arraynotcontainsanyof", "no trim"},
        {"startwithanyofhashed", "no trim"},
        {"notstartwithanyofhashed", "no trim"},
        {"endswithanyofhashed", "no trim"},
        {"notendswithanyofhashed", "no trim"},
        # semver comparator values trimmed because of backward compatibility
        {"semverisoneof", "4 trim"},
        {"semverisnotoneof", "5 trim"},
        {"semverless", "6 trim"},
        {"semverlessequals", "7 trim"},
        {"semvergreater", "8 trim"},
        {"semvergreaterequals", "9 trim"}
      ] do
    test "comparison value trimming - key: #{key}" do
      key = unquote(key)
      expected_return_value = unquote(expected_return_value)

      config =
        "comparison_value_trimming.json"
        |> fixture_file()
        |> LocalFileDataSource.new(:local_only)
        |> OverrideDataSource.overrides()

      user =
        User.new("12345",
          country: ~s(["USA"]),
          custom: %{
            "Version" => "1.0.0",
            "Number" => "3",
            "Date" => "1705253400"
          }
        )

      assert %EvaluationDetails{value: ^expected_return_value} = Rollout.evaluate(key, user, "default", nil, config)
    end
  end

  defp test_matrix(filename, sdk_key, type \\ @value_test_type) do
    [header | test_lines] = read_test_matrix(filename)
    {custom_key, settings_keys} = parse_header(header)

    {:ok, client} = start_config_cat(sdk_key)

    errors = Enum.flat_map(test_lines, &run_tests(&1, client, custom_key, settings_keys, type))

    assert errors == []
  end

  defp read_test_matrix(filename) do
    filename
    |> fixture_file()
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp parse_header(header) do
    [custom_key | settings_keys] =
      header
      |> String.split(";")
      |> Enum.drop(3)

    {custom_key, settings_keys}
  end

  defp run_tests(test_line, client, custom_key, settings_keys, type) do
    user = build_user(test_line, custom_key)

    expected_values =
      test_line
      |> String.split(";")
      |> Enum.drop(4)

    settings_keys
    |> Enum.zip(expected_values)
    |> Enum.map(fn {setting_key, expected} ->
      run_test(setting_key, expected, user, client, type)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_user(test_line, custom_key) do
    test_line =
      test_line
      |> String.split(";")
      |> Enum.take(4)

    case Enum.fetch(test_line, 0) do
      {:ok, "##null##"} ->
        nil

      _ ->
        [id, email, country, custom_value] = Enum.map(test_line, &normalize/1)

        User.new(id,
          email: email,
          country: country,
          custom: build_custom(custom_key, custom_value)
        )
    end
  end

  defp run_test(setting_key, expected, user, client, type) do
    actual =
      case type do
        @value_test_type ->
          ConfigCat.get_value(setting_key, nil, user, client: client)

        @variation_test_type ->
          ConfigCat.get_value_details(setting_key, nil, user, client: client).variation_id
      end

    unless equal?(actual, expected) do
      %{
        identifier: user && user.identifier,
        setting_key: setting_key,
        expected: to_string(expected),
        actual: to_string(actual)
      }
    end
  end

  defp equal?(actual, expected) when is_boolean(actual) do
    parsed = String.downcase(expected) == "true"
    parsed == actual
  end

  defp equal?(actual, expected) when is_integer(actual) do
    case Integer.parse(expected, 10) do
      {parsed, ""} -> parsed == actual
      _ -> false
    end
  end

  defp equal?(actual, expected) when is_float(actual) do
    case Float.parse(expected) do
      {parsed, ""} -> parsed == actual
      _ -> false
    end
  end

  defp equal?(actual, expected), do: actual == expected

  defp build_custom(_custom_key, nil), do: %{}
  defp build_custom(custom_key, custom_value), do: %{custom_key => custom_value}

  defp normalize(nil), do: nil
  defp normalize(""), do: nil
  defp normalize("##null##"), do: nil
  defp normalize(value), do: value
end
