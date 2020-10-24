defmodule ConfigCat.RolloutTest do
  use ExUnit.Case, async: true

  alias ConfigCat.{FetchPolicy, User}

  @moduletag capture_log: true

  @value_test_type "value_test"
  @variation_test_type "variation_test"

  test "basic rule evaluation" do
    test_matrix(
      "testmatrix.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A",
      @value_test_type
    )
  end

  test "semantic version matching" do
    test_matrix(
      "testmatrix_semantic.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/BAr3KgLTP0ObzKnBTo5nhA",
      @value_test_type
    )
  end

  test "semantic version comparisons" do
    test_matrix(
      "testmatrix_semantic_2.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w",
      @value_test_type
    )
  end

  test "semantic version comparisons #2" do
    test_matrix(
      "testmatrix_input_semantic_2.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w",
      @value_test_type
    )
  end

  test "numeric comparisons" do
    test_matrix(
      "testmatrix_number.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/uGyK3q9_ckmdxRyI7vjwCw",
      @value_test_type
    )
  end

  test "sensitive information comparisons" do
    test_matrix(
      "testmatrix_sensitive.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/qX3TP2dTj06ZpCCT1h_SPA",
      @value_test_type
    )
  end

  test "variation id" do
    test_matrix(
      "testmatrix_variationId.csv",
      "PKDVCLf-Hq-h-kCzMp-L7Q/nQ5qkhRAUEa6beEyyrVLBA",
      @variation_test_type
    )
  end

  test "invalid user object" do
    user = %{email: "a@configcat.com"}
    {:ok, client} = start_config_cat("PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
    actual = ConfigCat.get_value("stringContainsDogDefaultCat", "Lion", user, client: client)

    assert actual == "Cat"
  end

  defp test_matrix(filename, sdk_key, type) do
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

    Enum.zip(settings_keys, expected_values)
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
        @value_test_type -> ConfigCat.get_value(setting_key, nil, user, client: client)
        @variation_test_type -> ConfigCat.get_variation_id(setting_key, nil, user, client: client)
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

  defp build_custom(_custom_key, nil), do: nil
  defp build_custom(custom_key, custom_value), do: %{custom_key => custom_value}

  defp normalize(nil), do: nil
  defp normalize(""), do: nil
  defp normalize("##null##"), do: nil
  defp normalize(value), do: value

  defp start_config_cat(sdk_key) do
    name = UUID.uuid4() |> String.to_atom()

    with {:ok, _pid} <-
           ConfigCat.start_link(sdk_key,
             fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300),
             name: name
           ) do
      {:ok, name}
    else
      error -> error
    end
  end
end
