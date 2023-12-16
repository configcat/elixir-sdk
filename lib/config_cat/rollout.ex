defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.Config.EvaluationFormula
  alias ConfigCat.Config.PercentageRule
  alias ConfigCat.Config.RolloutRule
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.Rollout.Comparator
  alias ConfigCat.User

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @spec evaluate(
          Config.key(),
          User.t() | nil,
          Config.value(),
          Config.variation_id() | nil,
          Config.feature_flags()
        ) :: EvaluationDetails.t()
  def evaluate(key, user, default_value, default_variation_id, feature_flags) do
    {:ok, logs} = Agent.start(fn -> [] end)

    try do
      log_evaluating(logs, key, user)

      with {:ok, valid_user} <- validate_user(user),
           {:ok, setting_descriptor} <- setting_descriptor(feature_flags, key, default_value),
           setting_variation =
             EvaluationFormula.variation_id(setting_descriptor, default_variation_id),
           rollout_rules = EvaluationFormula.rollout_rules(setting_descriptor),
           percentage_rules = EvaluationFormula.percentage_rules(setting_descriptor),
           {value, variation, rule, percentage_rule} <-
             evaluate_rules(rollout_rules, percentage_rules, valid_user, key, logs) do
        variation = variation || setting_variation

        value =
          if value == :none do
            base_value(setting_descriptor, default_value, logs)
          else
            value
          end

        EvaluationDetails.new(
          key: key,
          matched_evaluation_rule: rule,
          matched_evaluation_percentage_rule: percentage_rule,
          user: user,
          value: value,
          variation_id: variation
        )
      else
        {:error, :invalid_user} ->
          log_invalid_user(key)
          evaluate(key, nil, default_value, default_variation_id, feature_flags)

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

  defp setting_descriptor(feature_flags, key, default_value) do
    case Map.fetch(feature_flags, key) do
      {:ok, descriptor} ->
        {:ok, descriptor}

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

  defp evaluate_rules([], [], _user, _key, _logs), do: {:none, nil, nil, nil}

  defp evaluate_rules(_rollout_rules, _percentage_rules, nil, key, _logs) do
    log_nil_user(key)
    {:none, nil, nil, nil}
  end

  defp evaluate_rules(rollout_rules, percentage_rules, user, key, logs) do
    case evaluate_rollout_rules(rollout_rules, user, key, logs) do
      {:none, _, _} ->
        {value, variation, rule} = evaluate_percentage_rules(percentage_rules, user, key)
        {value, variation, nil, rule}

      {value, variation, rule} ->
        {value, variation, rule, nil}
    end
  end

  defp evaluate_rollout_rules(rules, user, _key, logs) do
    Enum.reduce_while(rules, {:none, nil, nil}, &evaluate_rollout_rule(&1, &2, user, logs))
  end

  defp evaluate_rollout_rule(rule, default, user, logs) do
    comparison_attribute = RolloutRule.comparison_attribute(rule)
    comparison_value = RolloutRule.comparison_value(rule)
    comparator = RolloutRule.comparator(rule)
    value = RolloutRule.value(rule)
    variation = RolloutRule.variation_id(rule)

    case User.get_attribute(user, comparison_attribute) do
      nil ->
        log_no_match(logs, comparison_attribute, nil, comparator, comparison_value)
        {:cont, default}

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

            {:halt, {value, variation, rule}}

          {:ok, false} ->
            log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value)
            {:cont, default}

          {:error, error} ->
            log_validation_error(
              logs,
              comparison_attribute,
              user_value,
              comparator,
              comparison_value,
              error
            )

            {:cont, default}
        end
    end
  end

  defp evaluate_percentage_rules([] = _percentage_rules, _user, _key), do: {:none, nil, nil}

  defp evaluate_percentage_rules(percentage_rules, user, key) do
    hash_val = hash_user(user, key)

    Enum.reduce_while(
      percentage_rules,
      {0, nil, nil},
      &evaluate_percentage_rule(&1, &2, hash_val)
    )
  end

  defp evaluate_percentage_rule(rule, increment, hash_val) do
    {bucket, _v, _r} = increment
    bucket = increment_bucket(bucket, rule)

    if hash_val < bucket do
      percentage_value = PercentageRule.value(rule)
      variation_value = PercentageRule.variation_id(rule)

      {:halt, {percentage_value, variation_value, rule}}
    else
      {:cont, {bucket, nil, nil}}
    end
  end

  defp increment_bucket(bucket, rule), do: bucket + PercentageRule.percentage(rule)

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

  defp base_value(setting_descriptor, default_value, logs) do
    result = EvaluationFormula.value(setting_descriptor, default_value)
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
