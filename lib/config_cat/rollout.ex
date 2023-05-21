defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.{Config, Constants, User}
  alias ConfigCat.Rollout.Comparator

  require Logger
  require ConfigCat.Constants

  @spec evaluate(Config.key(), User.t() | nil, Config.value(), Config.variation_id(), Config.t()) ::
          {Config.value(), Config.variation_id()}
  def evaluate(key, user, default_value, default_variation_id, config) do
    log_evaluating(key)

    with {:ok, valid_user} <- validate_user(user),
         {:ok, feature_flags} = Map.fetch(config, Constants.feature_flags()),
         {:ok, setting_descriptor} <- Map.fetch(feature_flags, key),
         setting_variation <-
           Map.get(setting_descriptor, Constants.variation_id(), default_variation_id),
         rollout_rules <- Map.get(setting_descriptor, Constants.rollout_rules(), []),
         percentage_rules <- Map.get(setting_descriptor, Constants.percentage_rules(), []),
         {value, variation} <- evaluate_rules(rollout_rules, percentage_rules, valid_user, key) do
      variation = variation || setting_variation

      if value == :none do
        {base_value(setting_descriptor, default_value), variation}
      else
        {value, variation}
      end
    else
      {:error, :invalid_user} ->
        log_invalid_user(key)
        evaluate(key, nil, default_value, default_variation_id, config)

      :error ->
        log_no_value_found(key, default_value)
        {default_value, default_variation_id}
    end
  end

  defp validate_user(nil), do: {:ok, nil}
  defp validate_user(%User{} = user), do: {:ok, user}
  defp validate_user(_), do: {:error, :invalid_user}

  defp evaluate_rules([], [], _user, _key), do: {:none, nil}

  defp evaluate_rules(_rollout_rules, _percentage_rules, nil, key) do
    log_nil_user(key)
    {:none, nil}
  end

  defp evaluate_rules(rollout_rules, percentage_rules, user, key) do
    log_valid_user(user)
    {value, variation} = evaluate_rollout_rules(rollout_rules, user, key)

    if value == :none do
      evaluate_percentage_rules(percentage_rules, user, key)
    else
      {value, variation}
    end
  end

  defp evaluate_rollout_rules(rules, user, _key) do
    Enum.reduce_while(rules, {:none, nil}, &evaluate_rollout_rule(&1, &2, user))
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
              {:halt, {value, variation}}

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

  defp evaluate_percentage_rules([] = _percentage_rules, _user, _key), do: {:none, nil}

  defp evaluate_percentage_rules(percentage_rules, user, key) do
    hash_val = hash_user(user, key)

    Enum.reduce_while(percentage_rules, {0, nil}, &evaluate_percentage_rule(&1, &2, hash_val))
  end

  defp evaluate_percentage_rule(rule, increment, hash_val) do
    {bucket, _v} = increment
    bucket = increment_bucket(bucket, rule)

    if hash_val < bucket do
      percentage_value = Map.get(rule, Constants.value())
      variation_value = Map.get(rule, Constants.variation_id())

      {:halt, {percentage_value, variation_value}}
    else
      {:cont, {bucket, nil}}
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
    Logger.debug("Returning #{result}")

    result
  end

  defp log_evaluating(key) do
    Logger.debug("Evaluating get_value('#{key}').")
  end

  defp log_match(comparison_attribute, user_value, comparator, comparison_value, value) do
    Logger.debug(
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => match, returning: #{value}"
    )
  end

  defp log_no_match(comparison_attribute, user_value, comparator, comparison_value) do
    Logger.debug(
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => no match"
    )
  end

  defp log_validation_error(comparison_attribute, user_value, comparator, comparison_value, error) do
    Logger.warn(
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{Comparator.description(comparator)}] [#{comparison_value}] => SKIP rule. Validation error: #{inspect(error)}"
    )
  end

  defp log_no_value_found(key, default_value) do
    Logger.error(
      "Evaluating get_value('#{key}') failed. Value not found for key '#{key}'. Return default_value: [#{default_value}]."
    )
  end

  defp log_valid_user(user) do
    Logger.debug("User object: #{inspect(user)}")
  end

  defp log_nil_user(key) do
    Logger.warn(
      "Evaluating get_value('#{key}'). User struct missing! You should pass a User to get_value(), in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/"
    )
  end

  defp log_invalid_user(key) do
    Logger.warn("Evaluating get_value('#{key}'). User Object is not an instance of User struct.")
  end
end
