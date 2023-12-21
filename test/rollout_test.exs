defmodule ConfigCat.RolloutTest do
  use ExUnit.Case, async: true

  alias ConfigCat.CachePolicy
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

  @tag skip: "Not yet supported; needs new comparators"
  test "v6 comparators" do
    # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9a6b-4947-84e2-91529248278a/08dbc325-9ebd-4587-8171-88f76a3004cb
    test_matrix(
      "testmatrix_comparators_v6.csv",
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ"
    )
  end

  @tag skip: "Not yet supported; needs value type parsing"
  test "segments" do
    # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9cfb-486f-8906-72a57c693615/08dbc325-9ebd-4587-8171-88f76a3004cb
    test_matrix(
      "testmatrix_segments.csv",
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/h99HYXWWNE2bH8eWyLAVMA"
    )
  end

  @tag skip: "Not yet supported; needs value type parsing"
  test "segments (old)" do
    # https://app.configcat.com/08d5a03c-feb7-af1e-a1fa-40b3329f8bed/08d9f207-6883-43e5-868c-cbf677af3fe6/244cf8b0-f604-11e8-b543-f23c917f9d8d
    test_matrix(
      "testmatrix_segments_old.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/LcYz135LE0qbcacz2mgXnA"
    )
  end

  @tag skip: "Not yet supported; needs prerequisite flag conditions and new comparators"
  test "prerequisite flags" do
    # https://app.configcat.com/v2/e7a75611-4256-49a5-9320-ce158755e3ba/08dbc325-7f69-4fd4-8af4-cf9f24ec8ac9/08dbc325-9b74-45cb-86d0-4d61c25af1aa/08dbc325-9ebd-4587-8171-88f76a3004cb
    test_matrix(
      "testmatrix_prerequisite_flag.csv",
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg"
    )
  end

  @tag skip: "Not yet supported; needs new comparators"
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

  @tag skip: "Not yet supported; needs new comparators"
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

    if to_string(actual) !== to_string(expected) do
      %{
        identifier: user && user.identifier,
        setting_key: setting_key,
        expected: to_string(expected),
        actual: to_string(actual)
      }
    end
  end

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
