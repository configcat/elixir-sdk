defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.Rollout.Comparator
  alias ConfigCat.User

  require ConfigCat.Constants, as: Constants
  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @spec evaluate(
          Config.key(),
          User.t() | nil,
          Config.value(),
          Config.variation_id() | nil,
          Config.settings()
        ) :: EvaluationDetails.t()
  def evaluate(key, user, default_value, default_variation_id, settings) do
    log_evaluating(key)

    with {:ok, valid_user} <- validate_user(user),
         {:ok, setting_descriptor} <- setting_descriptor(settings, key, default_value),
         setting_variation <-
           Map.get(setting_descriptor, Constants.variation_id(), default_variation_id),
         rollout_rules <- Map.get(setting_descriptor, Constants.rollout_rules(), []),
         percentage_rules <- Map.get(setting_descriptor, Constants.percentage_rules(), []),
         {value, variation, rule, percentage_rule} <-
           evaluate_rules(rollout_rules, percentage_rules, valid_user, key) do
      variation = variation || setting_variation

      value =
        if value == :none do
          base_value(setting_descriptor, default_value)
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
        evaluate(key, nil, default_value, default_variation_id, settings)

      {:error, message} ->
        ConfigCatLogger.error(message)

        EvaluationDetails.new(
          default_value?: true,
          error: message,
          key: key,
          user: user,
          value: default_value,
          variation_id: default_variation_id
        )
    end
  end

  defp validate_user(nil), do: {:ok, nil}
  defp validate_user(%User{} = user), do: {:ok, user}
  defp validate_user(_), do: {:error, :invalid_user}

  defp setting_descriptor(settings, key, default_value) do
    case Map.fetch(settings, key) do
      {:ok, descriptor} ->
        {:ok, descriptor}

      :error ->
        available_keys =
          settings
          |> Map.keys()
          |> Enum.map_join(", ", &"'#{&1}'")

        message =
          "Failed to evaluate setting '#{key}' (the key was not found in config JSON). " <>
            "Returning the `default_value` parameter that you specified in your application: '#{default_value}'. " <>
            "Available keys: [#{available_keys}]."

        {:error, message}
    end
  end

  defp evaluate_rules([], [], _user, _key), do: {:none, nil, nil, nil}

  defp evaluate_rules(_rollout_rules, _percentage_rules, nil, key) do
    log_nil_user(key)
    {:none, nil, nil, nil}
  end

  defp evaluate_rules(rollout_rules, percentage_rules, user, key) do
    log_valid_user(user)

    case evaluate_rollout_rules(rollout_rules, user, key) do
      {:none, _, _} ->
        {value, variation, rule} = evaluate_percentage_rules(percentage_rules, user, key)
        {value, variation, nil, rule}

      {value, variation, rule} ->
        {value, variation, rule, nil}
    end
  end

  defp evaluate_rollout_rules(rules, user, _key) do
    Enum.reduce_while(rules, {:none, nil, nil}, &evaluate_rollout_rule(&1, &2, user))
  end

  defp evaluate_rollout_rule(rule, default, user) do
    with comparison_attribute <- Map.get(rule, Constants.comparison_attribute()),
         comparison_value <- Map.get(rule, Constants.comparison_value()),
         comparator <- Map.get(rule, Constants.comparator()),
         value <- Map.get(rule, Constants.value()),
         variation <- Map.get(rule, Constants.variation_id()) do
      case User.get_attribute(user, comparison_attribute) do
        nil ->
          log_no_match(comparison_attribute, nil, comparator, comparison_value)
          {:cont, default}

        user_value ->
          case Comparator.compare(comparator, to_string(user_value), to_string(comparison_value)) do
            {:ok, true} ->
              log_match(comparison_attribute, user_value, comparator, comparison_value, value)
              {:halt, {value, variation, rule}}

            {:ok, false} ->
              log_no_match(comparison_attribute, user_value, comparator, comparison_value)
              {:cont, default}

            {:error, error} ->
              log_validation_error(
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
      percentage_value = Map.get(rule, Constants.value())
      variation_value = Map.get(rule, Constants.variation_id())

      {:halt, {percentage_value, variation_value, rule}}
    else
      {:cont, {bucket, nil, nil}}
    end
  end

  defp increment_bucket(bucket, rule), do: bucket + Map.get(rule, Constants.percentage(), 0)

  defp hash_user(user, key) do
    user_key = User.get_attribute(user, "Identifier")
    hash_candidate = "#{key}#{user_key}"

    {hash_value, _} =
      :crypto.hash(:sha, hash_candidate)
      |> Base.encode16()
      |> String.slice(0, 7)
      |> Integer.parse(16)

    rem(hash_value, 100)
  end

  defp base_value(setting_descriptor, default_value) do
    result = Map.get(setting_descriptor, Constants.value(), default_value)
    ConfigCatLogger.debug("Returning #{result}")

    result
  end

  defp log_evaluating(key) do
    ConfigCatLogger.debug("Evaluating get_value('#{key}').")
  end

  defp log_match(comparison_attribute, user_value, comparator, comparison_value, value) do
    ConfigCatLogger.debug(
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => match, returning: #{value}"
    )
  end

  defp log_no_match(comparison_attribute, user_value, comparator, comparison_value) do
    ConfigCatLogger.debug(
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => no match"
    )
  end

  defp log_validation_error(comparison_attribute, user_value, comparator, comparison_value, error) do
    ConfigCatLogger.warn(
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => SKIP rule. Validation error: #{inspect(error)}"
    )
  end

  defp log_valid_user(user) do
    ConfigCatLogger.debug("User object: #{inspect(user)}")
  end

  defp log_nil_user(key) do
    ConfigCatLogger.warn(
      "Evaluating get_value('#{key}'). User struct missing! You should pass a User to get_value(), in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/"
    )
  end

  defp log_invalid_user(key) do
    ConfigCatLogger.warn(
      "Evaluating get_value('#{key}'). User Object is not an instance of User struct."
    )
  end
end
