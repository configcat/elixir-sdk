defmodule ConfigCat.EvaluationLogTest do
  # We change the logging level for these tests, so we run them synchronously.
  use ConfigCat.Case, async: false

  import ExUnit.CaptureLog

  alias ConfigCat.CachePolicy
  alias ConfigCat.LocalFileDataSource
  alias ConfigCat.NullDataSource
  alias ConfigCat.User

  @moduletag capture_log: true

  setup do
    original_level = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: original_level) end)
  end

  test "simple value" do
    test_evaluation_log("simple_value.json")
  end

  test "1 targeting rule" do
    test_evaluation_log("1_targeting_rule.json")
  end

  test "2 targeting rules" do
    test_evaluation_log("2_targeting_rules.json")
  end

  test "options based on user id" do
    test_evaluation_log("options_based_on_user_id.json")
  end

  test "options based on custom attr" do
    test_evaluation_log("options_based_on_custom_attr.json")
  end

  test "options after targeting rule" do
    test_evaluation_log("options_after_targeting_rule.json")
  end

  test "options within targeting rule" do
    test_evaluation_log("options_within_targeting_rule.json")
  end

  test "and rules" do
    test_evaluation_log("and_rules.json")
  end

  test "segment" do
    test_evaluation_log("segment.json")
  end

  test "prerequisite flag" do
    test_evaluation_log("prerequisite_flag.json")
  end

  test "semver validation" do
    test_evaluation_log("semver_validation.json")
  end

  test "epoch date validation" do
    test_evaluation_log("epoch_date_validation.json")
  end

  test "number validation" do
    test_evaluation_log("number_validation.json")
  end

  test "comparators validation" do
    # self.maxDiff = None
    test_evaluation_log("comparators.json")
  end

  test "list truncation validation" do
    test_evaluation_log("list_truncation.json")
  end

  defp test_evaluation_log(filename) do
    file_path = "evaluation" |> Path.join(filename) |> fixture_file()
    suite_name = Path.basename(file_path, ".json")
    suite_sub_dir = file_path |> Path.dirname() |> Path.join(suite_name)
    data = file_path |> File.read!() |> Jason.decode!()
    sdk_key = Map.get(data, "sdkKey", "configcat-sdk-test-key/0000000000000000000000")
    json_override = data["jsonOverride"]

    overrides =
      if json_override do
        LocalFileDataSource.new(Path.join(suite_sub_dir, json_override), :local_only)
      else
        NullDataSource.new()
      end

    {:ok, client} = start_config_cat(sdk_key, fetch_policy: CachePolicy.manual(), flag_overrides: overrides)
    ConfigCat.force_refresh(client: client)

    Enum.each(data["tests"], &run_test(&1, client, suite_sub_dir))
  end

  defp run_test(test, client, suite_sub_dir) do
    %{"key" => key, "defaultValue" => default_value, "returnValue" => return_value, "expectedLog" => expected_log_file} =
      test

    user = build_user(test["user"])

    # test_name = Path.basename(expected_log_file, ".txt")
    expected_log = File.read!(Path.join(suite_sub_dir, expected_log_file))

    log =
      capture_log(fn ->
        assert return_value == ConfigCat.get_value(key, default_value, user, client: client)
      end)

    {expected_clean_log, expected_user} = extract_logged_user(expected_log)
    {clean_log, actual_user} = extract_logged_user(log)

    assert clean_log == expected_clean_log
    assert actual_user == expected_user
  end

  defp build_user(nil), do: nil

  defp build_user(user_attrs) do
    {attrs, custom} = Map.split(user_attrs, ["Country", "Email", "Identifier"])

    User.new(attrs["Identifier"], country: attrs["Country"], custom: custom, email: attrs["Email"])
  end

  @logged_user_regex ~r/for User '(\{.*?\})'/
  defp extract_logged_user(log) do
    case Regex.run(@logged_user_regex, log) do
      nil ->
        {log, nil}

      [_entire_match, logged_user] ->
        {Regex.replace(@logged_user_regex, log, ""), Jason.decode!(logged_user)}
    end
  end
end
