defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.Config.ComparisonRule
  alias ConfigCat.Config.Condition
  alias ConfigCat.Config.EvaluationFormula
  alias ConfigCat.Config.PercentageOption
  alias ConfigCat.Config.TargetingRule
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.Rollout.Comparator
  alias ConfigCat.User

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @spec evaluate(
          Config.key(),
          User.t() | nil,
          Config.value(),
          Config.variation_id() | nil,
          Config.t()
        ) :: EvaluationDetails.t()
  def evaluate(key, user, default_value, default_variation_id, config) do
    {:ok, logs} = Agent.start(fn -> [] end)

    try do
      log_evaluating(logs, key, user)

      with {:ok, valid_user} <- validate_user(user),
           feature_flags = Config.feature_flags(config),
           {:ok, formula} <- evaluation_formula(feature_flags, key, default_value) do
        percentage_options = EvaluationFormula.percentage_options(formula)
        setting_type = EvaluationFormula.setting_type(formula)
        targeting_rules = EvaluationFormula.targeting_rules(formula)

        {value, variation, rule, percentage_option} =
          evaluate_rules(targeting_rules, percentage_options, setting_type, valid_user, key, logs)

        if value == :none do
          EvaluationDetails.new(
            key: key,
            user: user,
            value: base_value(formula, default_value, logs),
            variation_id: EvaluationFormula.variation_id(formula, default_variation_id)
          )
        else
          EvaluationDetails.new(
            key: key,
            matched_evaluation_rule: rule,
            matched_evaluation_percentage_rule: percentage_option,
            user: user,
            value: value,
            variation_id: variation
          )
        end
      else
        {:error, :invalid_user} ->
          log_invalid_user(key)
          evaluate(key, nil, default_value, default_variation_id, config)

        {:error, message} ->
          ConfigCatLogger.error(message, event_id: 1001)

          EvaluationDetails.new(
            default_value?: true,
            error: message,
            key: key,
            value: default_value,
            variation_id: default_variation_id
          )
      end
    after
      logs
      |> Agent.get(& &1)
      |> Enum.reverse()
      |> Enum.join("\n")
      |> ConfigCatLogger.debug(event_id: 5000)

      Agent.stop(logs)
    end
  end

  defp validate_user(nil), do: {:ok, nil}
  defp validate_user(%User{} = user), do: {:ok, user}
  defp validate_user(_), do: {:error, :invalid_user}

  defp evaluation_formula(feature_flags, key, default_value) do
    case Map.fetch(feature_flags, key) do
      {:ok, formula} ->
        {:ok, formula}

      :error ->
        available_keys =
          feature_flags
          |> Map.keys()
          |> Enum.map_join(", ", &"'#{&1}'")

        message =
          "Failed to evaluate setting '#{key}' (the key was not found in config JSON). " <>
            "Returning the `default_value` parameter that you specified in your application: '#{default_value}'. " <>
            "Available keys: [#{available_keys}]."

        {:error, message}
    end
  end

  defp evaluate_rules([], [], _setting_type, _user, _key, _logs), do: {:none, nil, nil, nil}

  defp evaluate_rules(_targeting_rules, _percentage_options, _setting_type, nil, key, _logs) do
    log_nil_user(key)
    {:none, nil, nil, nil}
  end

  defp evaluate_rules(targeting_rules, percentage_options, setting_type, user, key, logs) do
    case evaluate_targeting_rules(targeting_rules, setting_type, user, key, logs) do
      {:none, _, _} ->
        {value, variation, option} = evaluate_percentage_options(percentage_options, user, key)
        {value, variation, nil, option}

      {value, variation, rule} ->
        {value, variation, rule, nil}
    end
  end

  defp evaluate_targeting_rules(rules, setting_type, user, _key, logs) do
    Enum.reduce_while(rules, {:none, nil, nil}, fn rule, acc ->
      conditions = TargetingRule.conditions(rule)
      value = TargetingRule.value(rule, setting_type)
      variation_id = TargetingRule.variation_id(rule)

      if Enum.all?(conditions, &evaluate_condition(&1, user, value, logs)) do
        {:halt, {value, variation_id, rule}}
      else
        {:cont, acc}
      end
    end)
  end

  defp evaluate_condition(condition, user, value, logs) do
    user_condition = Condition.user_condition(condition)

    if user_condition do
      evaluate_user_condition(user_condition, user, value, logs)
    else
      true
    end
  end

  defp evaluate_user_condition(comparison_rule, user, value, logs) do
    comparison_attribute = ComparisonRule.comparison_attribute(comparison_rule)
    comparator = ComparisonRule.comparator(comparison_rule)
    # TODO: Get correct type based on comparator
    comparison_value = ComparisonRule.string_value(comparison_rule)

    case User.get_attribute(user, comparison_attribute) do
      nil ->
        log_no_match(logs, comparison_attribute, nil, comparator, comparison_value)
        false

      user_value ->
        case Comparator.compare(comparator, to_string(user_value), to_string(comparison_value)) do
          {:ok, true} ->
            log_match(
              logs,
              comparison_attribute,
              user_value,
              comparator,
              comparison_value,
              value
            )

            true

          {:ok, false} ->
            log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value)
            false

          {:error, error} ->
            log_validation_error(
              logs,
              comparison_attribute,
              user_value,
              comparator,
              comparison_value,
              error
            )

            false
        end
    end
  end

  defp evaluate_percentage_options([] = _percentage_options, _user, _key), do: {:none, nil, nil}

  defp evaluate_percentage_options(percentage_options, user, key) do
    hash_val = hash_user(user, key)

    Enum.reduce_while(
      percentage_options,
      {0, nil, nil},
      &evaluate_percentage_option(&1, &2, hash_val)
    )
  end

  defp evaluate_percentage_option(rule, increment, hash_val) do
    {bucket, _v, _r} = increment
    bucket = increment_bucket(bucket, rule)

    if hash_val < bucket do
      percentage_value = PercentageOption.value(rule)
      variation_value = PercentageOption.variation_id(rule)

      {:halt, {percentage_value, variation_value, rule}}
    else
      {:cont, {bucket, nil, nil}}
    end
  end

  defp increment_bucket(bucket, rule), do: bucket + PercentageOption.percentage(rule)

  defp hash_user(user, key) do
    user_key = User.get_attribute(user, "Identifier")
    hash_candidate = "#{key}#{user_key}"

    {hash_value, _} =
      :sha
      |> :crypto.hash(hash_candidate)
      |> Base.encode16()
      |> String.slice(0, 7)
      |> Integer.parse(16)

    rem(hash_value, 100)
  end

  defp base_value(formula, default_value, logs) do
    result = EvaluationFormula.value(formula, default_value)

    log(logs, "Returning #{result}")

    result
  end

  defp log_evaluating(logs, key, user) do
    log(logs, "Evaluating get_value('#{key}). User object:\n#{inspect(user)}")
  end

  defp log_match(logs, comparison_attribute, user_value, comparator, comparison_value, value) do
    log(
      logs,
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => match, returning: #{value}"
    )
  end

  defp log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value) do
    log(
      logs,
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => no match"
    )
  end

  defp log_validation_error(logs, comparison_attribute, user_value, comparator, comparison_value, error) do
    message =
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => SKIP rule. Validation error: #{inspect(error)}"

    ConfigCatLogger.warning(message)
    log(logs, message)
  end

  defp log_nil_user(key) do
    ConfigCatLogger.warning(
      "Cannot evaluate targeting rules and % options for setting '#{key}' (User Object is missing). " <>
        "You should pass a User Object to the evaluation functions like `get_value()` in order to make targeting work properly. " <>
        "Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3001
    )
  end

  defp log_invalid_user(key) do
    ConfigCatLogger.warning(
      "Cannot evaluate targeting rules and % options for setting '#{key}' (User Object is not an instance of User struct).",
      event_id: 4001
    )
  end

  defp log(logs, message) do
    Agent.update(logs, &[message | &1])
  end
end
