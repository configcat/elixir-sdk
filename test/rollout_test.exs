defmodule ConfigCat.RolloutTest do
  use ExUnit.Case, async: true

  alias ConfigCat.{FetchPolicy, User}

  @moduletag capture_log: true

  test "basic rule evaluation" do
    test_matrix("testmatrix.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
  end

  test "semantic version matching" do
    test_matrix("testmatrix_semantic.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/BAr3KgLTP0ObzKnBTo5nhA")
  end

  test "semantic version comparisons" do
    test_matrix("testmatrix_semantic_2.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w")
  end

  test "semantic version comparisons #2" do
    test_matrix("testmatrix_input_semantic_2.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w")
  end

  test "numeric comparisons" do
    test_matrix("testmatrix_number.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/uGyK3q9_ckmdxRyI7vjwCw")
  end

  test "sensitive information comparisons" do
    test_matrix("testmatrix_sensitive.csv", "PKDVCLf-Hq-h-kCzMp-L7Q/qX3TP2dTj06ZpCCT1h_SPA")
  end

  test "invalid user object" do
    user = %{email: "a@configcat.com"}
    {:ok, client} = start_config_cat("PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
    actual = ConfigCat.get_value("stringContainsDogDefaultCat", "Lion", user, client: client)

    assert actual == "Cat"
  end

  defp test_matrix(filename, sdk_key) do
    [header | test_lines] = read_test_matrix(filename)
    {custom_key, settings_keys} = parse_header(header)

    {:ok, client} = start_config_cat(sdk_key)

    errors = Enum.flat_map(test_lines, &run_tests(&1, client, custom_key, settings_keys))

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

  defp run_tests(test_line, client, custom_key, settings_keys) do
    user = build_user(test_line, custom_key)

    expected_values =
      test_line
      |> String.split(";")
      |> Enum.drop(4)

    Enum.zip(settings_keys, expected_values)
    |> Enum.map(fn {setting_key, expected} -> run_test(setting_key, expected, user, client) end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_user(test_line, custom_key) do
    [id, email, country, custom_value] =
      test_line
      |> String.split(";")
      |> Enum.take(4)
      |> Enum.map(&normalize/1)

    if id do
      User.new(id, email: email, country: country, custom: build_custom(custom_key, custom_value))
    else
      nil
    end
  end

  defp run_test(setting_key, expected, user, client) do
    actual = ConfigCat.get_value(setting_key, nil, user, client: client)

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

    ConfigCat.start_link(sdk_key,
      fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 300),
      name: name
    )
  end
end
