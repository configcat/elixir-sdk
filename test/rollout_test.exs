defmodule ConfigCat.RolloutTest do
  use ExUnit.Case, async: true

  alias ConfigCat.CachePolicy
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.User

  @moduletag capture_log: true

  @value_test_type "value_test"
  @variation_test_type "variation_test"

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

  @tag skip: "Not yet supported; needs prerequisite flag conditions"
  test "prerequisite flags" do
    # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9b74-45cb-86d0-4d61c25af1aa/08dbc325-9ebd-4587-8171-88f76a3004cb
    test_matrix(
      "testmatrix_prerequisite_flag.csv",
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg"
    )
  end

  @tag skip: "Not yet supported; needs prerequisite flag conditions"
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

  test "invalid user object" do
    user = %{email: "a@configcat.com"}
    {:ok, client} = start_config_cat("PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
    actual = ConfigCat.get_value("stringContainsDogDefaultCat", "Lion", user, client: client)

    assert actual == "Cat"
  end

  defp test_matrix(filename, sdk_key, type \\ @value_test_type) do
    [header | test_lines] = read_test_matrix(filename)
    {custom_key, settings_keys} = parse_header(header)

    {:ok, client} = start_config_cat(sdk_key)

    errors = Enum.flat_map(test_lines, &run_tests(&1, client, custom_key, settings_keys, type))

    assert errors == []
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

  defp read_test_matrix(filename) do
    __ENV__.file
    |> Path.dirname()
    |> Path.join("fixtures/#{filename}")
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

  defp start_config_cat(sdk_key) do
    name = String.to_atom(UUID.uuid4())

    with {:ok, _pid} <-
           start_supervised(
             {ConfigCat,
              [
                fetch_policy: CachePolicy.lazy(cache_refresh_interval_seconds: 300),
                name: name,
                sdk_key: sdk_key
              ]}
           ) do
      {:ok, name}
    end
  end
end
