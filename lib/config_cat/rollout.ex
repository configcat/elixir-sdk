defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.Config.ComparisonRule
  alias ConfigCat.Config.Condition
  alias ConfigCat.Config.EvaluationFormula
  alias ConfigCat.Config.PercentageOption
  alias ConfigCat.Config.Preferences
  alias ConfigCat.Config.Segment
  alias ConfigCat.Config.SegmentComparator
  alias ConfigCat.Config.SegmentCondition
  alias ConfigCat.Config.TargetingRule
  alias ConfigCat.Config.UserComparator
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.User

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  defmodule Context do
    @moduledoc false
    use TypedStruct

    alias ConfigCat.Config.SettingType

    typedstruct enforce: true do
      field :config, Config.t()
      field :key, Config.key()
      field :logs, pid()
      field :setting_type, SettingType.t()
      field :user, User.t(), enforce: false
    end
  end

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
        context = %Context{
          config: config,
          key: key,
          logs: logs,
          setting_type: EvaluationFormula.setting_type(formula),
          user: valid_user
        }

        percentage_options = EvaluationFormula.percentage_options(formula)
        targeting_rules = EvaluationFormula.targeting_rules(formula)

        {value, variation, rule, percentage_option} =
          evaluate_rules(targeting_rules, percentage_options, context)

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
            matched_targeting_rule: rule,
            matched_percentage_option: percentage_option,
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

  defp evaluate_rules([], [], _context), do: {:none, nil, nil, nil}

  defp evaluate_rules(targeting_rules, percentage_options, context) do
    case evaluate_targeting_rules(targeting_rules, context) do
      {:none, _, _, _} ->
        {value, variation, option} = evaluate_percentage_options(percentage_options, context)
        {value, variation, nil, option}

      {value, variation, rule, option} ->
        {value, variation, rule, option}
    end
  end

  defp evaluate_targeting_rules(rules, %Context{} = context) do
    salt = context.config |> Config.preferences() |> Preferences.salt()
    segments = Config.segments(context.config)

    Enum.reduce_while(rules, {:none, nil, nil, nil}, fn rule, acc ->
      case evaluate_targeting_rule(rule, salt, segments, context) do
        {:none, _, _, _} -> {:cont, acc}
        result -> {:halt, result}
      end
    end)
  end

  defp evaluate_targeting_rule(rule, salt, segments, %Context{} = context) do
    conditions = TargetingRule.conditions(rule)
    value = TargetingRule.value(rule, context.setting_type)

    if Enum.all?(conditions, &evaluate_condition(&1, salt, value, segments, context)) do
      case TargetingRule.served_value(rule) do
        nil ->
          percentage_options = TargetingRule.percentage_options(rule)
          {value, variation_id, option} = evaluate_percentage_options(percentage_options, context)
          {value, variation_id, rule, option}

        _ ->
          variation_id = TargetingRule.variation_id(rule)
          {value, variation_id, rule, nil}
      end
    else
      {:none, nil, nil, nil}
    end
  end

  defp evaluate_condition(condition, salt, value, segments, %Context{} = context) do
    segment_condition = Condition.segment_condition(condition)
    user_condition = Condition.user_condition(condition)

    cond do
      user_condition ->
        evaluate_user_condition(user_condition, context.key, salt, value, context)

      segment_condition ->
        evaluate_segment_condition(segment_condition, salt, value, segments, context)

      true ->
        true
    end
  end

  defp evaluate_user_condition(_comparison_rule, _context_salt, _salt, _value, %Context{user: nil} = context) do
    log_nil_user(context.key)
    false
  end

  defp evaluate_user_condition(comparison_rule, context_salt, salt, value, %Context{} = context) do
    %Context{logs: logs, user: user} = context
    comparison_attribute = ComparisonRule.comparison_attribute(comparison_rule)
    comparator = ComparisonRule.comparator(comparison_rule)
    comparison_value = ComparisonRule.comparison_value(comparison_rule)

    case User.get_attribute(user, comparison_attribute) do
      nil = user_value ->
        log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value)
        false

      user_value ->
        case UserComparator.compare(comparator, user_value, comparison_value, context_salt, salt) do
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

  defp evaluate_segment_condition(_condition, _salt, _value, _segments, %Context{user: nil} = context) do
    log_nil_user(context.key)
    false
  end

  defp evaluate_segment_condition(condition, salt, value, segments, %Context{} = context) do
    index = SegmentCondition.segment_index(condition)
    segment = Enum.fetch!(segments, index)
    comparator = SegmentCondition.segment_comparator(condition)
    name = Segment.name(segment)
    rules = Segment.segment_rules(segment)
    in_segment? = Enum.all?(rules, &evaluate_user_condition(&1, name, salt, value, context))
    SegmentComparator.compare(comparator, in_segment?)
  end

  defp evaluate_percentage_options([] = _percentage_options, _context), do: {:none, nil, nil}

  defp evaluate_percentage_options(_percentage_options, %Context{user: nil} = context) do
    log_nil_user(context.key)
    {:none, nil, nil}
  end

  defp evaluate_percentage_options(percentage_options, %Context{} = context) do
    hash_val = hash_user(context.user, context.key)

    Enum.reduce_while(
      percentage_options,
      {0, nil, nil},
      &evaluate_percentage_option(&1, &2, hash_val, context)
    )
  end

  defp evaluate_percentage_option(option, increment, hash_val, %Context{} = context) do
    {bucket, _v, _r} = increment
    bucket = bucket + PercentageOption.percentage(option)

    if hash_val < bucket do
      value = PercentageOption.value(option, context.setting_type)
      variation_id = PercentageOption.variation_id(option)

      {:halt, {value, variation_id, option}}
    else
      {:cont, {bucket, nil, nil}}
    end
  end

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
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{UserComparator.description(comparator)}] [#{comparison_value}] => match, returning: #{value}"
    )
  end

  defp log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value) do
    log(
      logs,
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{UserComparator.description(comparator)}] [#{comparison_value}] => no match"
    )
  end

  defp log_validation_error(logs, comparison_attribute, user_value, comparator, comparison_value, error) do
    message =
      "Evaluating rule: [#{comparison_attribute}:#{user_value}] [#{UserComparator.description(comparator)}] [#{comparison_value}] => SKIP rule. Validation error: #{inspect(error)}"

    ConfigCatLogger.warning(message)
    log(logs, message)
  end

  defp log_nil_user(key) do
    ConfigCatLogger.warning(
      "Cannot evaluate targeting rules and % options for setting '#{key}' " <>
        "(User Object is missing). " <>
        "You should pass a User Object to the evaluation functions like `get_value()` " <>
        "in order to make targeting work properly. " <>
        "Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3001
    )
  end

  defp log_invalid_user(key) do
    ConfigCatLogger.warning(
      "Cannot evaluate targeting rules and % options for setting '#{key}' " <>
        "(User Object is not an instance of User struct)." <>
        "You should pass a User Object to the evaluation functions like `get_value()` " <>
        "in order to make targeting work properly. " <>
        "Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 4001
    )
  end

  defp log(logs, message) do
    Agent.update(logs, &[message | &1])
  end
end
