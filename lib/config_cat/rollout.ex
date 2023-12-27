defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.Config.Condition
  alias ConfigCat.Config.PercentageOption
  alias ConfigCat.Config.PrerequisiteFlagComparator
  alias ConfigCat.Config.PrerequisiteFlagCondition
  alias ConfigCat.Config.Segment
  alias ConfigCat.Config.SegmentComparator
  alias ConfigCat.Config.SegmentCondition
  alias ConfigCat.Config.Setting
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.TargetingRule
  alias ConfigCat.Config.UserComparator
  alias ConfigCat.Config.UserCondition
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.User

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  defmodule CircularDependencyError do
    @moduledoc false
    @enforce_keys [:prerequisite_key, :visited_keys]
    defexception [:prerequisite_key, :visited_keys]

    @type option :: {:prerequisite_key, String.t()} | {:visited_keys, [String.t()]}
    @type t :: %__MODULE__{
            prerequisite_key: String.t(),
            visited_keys: [String.t()]
          }

    @impl Exception
    def exception(options) do
      struct!(__MODULE__, options)
    end

    @impl Exception
    def message(%__MODULE__{} = error) do
      depending_flags =
        [error.prerequisite_key | error.visited_keys]
        |> Enum.reverse()
        |> Enum.map_join(" -> ", &"'#{&1}'")

      "Circular dependency detected between the following depending flags: #{depending_flags}"
    end
  end

  defmodule EvaluationError do
    @moduledoc false
    @enforce_keys [:message]
    defexception [:message]

    @type t :: %__MODULE__{
            message: String.t()
          }
  end

  defmodule Context do
    @moduledoc false
    use TypedStruct

    alias ConfigCat.Config.SettingType

    typedstruct enforce: true do
      field :config, Config.t()
      field :key, Config.key()
      field :logs, pid() | nil
      field :percentage_option_attribute, String.t(), enforce: false
      field :salt, Config.salt()
      field :setting_type, SettingType.t()
      field :user, User.t(), enforce: false
      field :visited_keys, [String.t()]
    end
  end

  @spec evaluate(
          Config.key(),
          User.t() | nil,
          Config.value() | nil,
          Config.variation_id() | nil,
          Config.t(),
          pid() | nil,
          [String.t()]
        ) :: EvaluationDetails.t()
  def evaluate(key, user, default_value, default_variation_id, config, logs \\ nil, visited_keys \\ []) do
    log_evaluating(logs, key, user)

    with {:ok, valid_user} <- validate_user(user),
         settings = Config.settings(config),
         {:ok, setting} <- setting(settings, key, default_value) do
      context = %Context{
        config: config,
        key: key,
        logs: logs,
        percentage_option_attribute: Setting.percentage_option_attribute(setting),
        salt: Setting.salt(setting),
        setting_type: Setting.setting_type(setting),
        user: valid_user,
        visited_keys: visited_keys
      }

      percentage_options = Setting.percentage_options(setting)
      targeting_rules = Setting.targeting_rules(setting)

      {value, variation, rule, percentage_option} =
        evaluate_rules(targeting_rules, percentage_options, context)

      if value == :none do
        EvaluationDetails.new(
          key: key,
          user: user,
          value: base_value(setting, default_value, logs),
          variation_id: Setting.variation_id(setting, default_variation_id)
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
        evaluate(key, nil, default_value, default_variation_id, config, logs, visited_keys)

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
  rescue
    error ->
      if visited_keys == [] do
        message =
          "Failed to evaluate setting '#{key}'. (#{Exception.message(error)}). " <>
            "Returning the default_value parameter that you specified in your application: '#{default_value}'."

        ConfigCatLogger.error(message, event_id: 2001)

        EvaluationDetails.new(
          default_value?: true,
          error: message,
          key: key,
          value: default_value,
          variation_id: default_variation_id
        )
      else
        reraise(error, __STACKTRACE__)
      end
  end

  defp validate_user(nil), do: {:ok, nil}
  defp validate_user(%User{} = user), do: {:ok, user}
  defp validate_user(_), do: {:error, :invalid_user}

  defp setting(settings, key, default_value) do
    case Map.fetch(settings, key) do
      {:ok, setting} ->
        {:ok, setting}

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
    Enum.reduce_while(rules, {:none, nil, nil, nil}, fn rule, acc ->
      case evaluate_targeting_rule(rule, context) do
        {:none, _, _, _} -> {:cont, acc}
        result -> {:halt, result}
      end
    end)
  end

  defp evaluate_targeting_rule(rule, %Context{} = context) do
    conditions = TargetingRule.conditions(rule)
    value = TargetingRule.value(rule, context.setting_type)

    if evaluate_conditions(conditions, value, context) do
      case TargetingRule.simple_value(rule) do
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

  defp evaluate_conditions(conditions, value, context) do
    Enum.reduce_while(conditions, true, fn condition, acc ->
      case evaluate_condition(condition, value, context) do
        {:ok, true} -> {:cont, acc}
        {:ok, false} -> {:halt, false}
        {:error, _error} -> {:halt, false}
      end
    end)
  end

  defp evaluate_condition(condition, value, %Context{} = context) do
    prerequisite_flag_condition = Condition.prerequisite_flag_condition(condition)
    segment_condition = Condition.segment_condition(condition)
    user_condition = Condition.user_condition(condition)

    cond do
      user_condition ->
        evaluate_user_condition(user_condition, context.key, value, context)

      segment_condition ->
        evaluate_segment_condition(segment_condition, value, context)

      prerequisite_flag_condition ->
        evaluate_prerequisite_flag_condition(prerequisite_flag_condition, context)

      true ->
        {:ok, true}
    end
  end

  defp evaluate_user_condition(_comparison_rule, _context_salt, _value, %Context{user: nil} = context) do
    log_nil_user(context.key)
    {:ok, false}
  end

  defp evaluate_user_condition(comparison_rule, context_salt, value, %Context{} = context) do
    %Context{logs: logs, salt: salt, user: user} = context
    comparison_attribute = UserCondition.comparison_attribute(comparison_rule)
    comparator = UserCondition.comparator(comparison_rule)
    comparison_value = UserCondition.comparison_value(comparison_rule)

    case User.get_attribute(user, comparison_attribute) do
      nil = user_value ->
        log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value)
        {:error, :missing_comparison_attribute}

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

            {:ok, true}

          {:ok, false} ->
            log_no_match(logs, comparison_attribute, user_value, comparator, comparison_value)
            {:ok, false}

          {:error, error} ->
            log_validation_error(
              logs,
              comparison_attribute,
              user_value,
              comparator,
              comparison_value,
              error
            )

            {:error, error}
        end
    end
  end

  defp evaluate_segment_condition(_condition, _value, %Context{user: nil} = context) do
    log_nil_user(context.key)
    {:ok, false}
  end

  defp evaluate_segment_condition(condition, value, %Context{} = context) do
    segment = SegmentCondition.segment(condition)
    comparator = SegmentCondition.segment_comparator(condition)
    name = Segment.name(segment)

    segment
    |> Segment.conditions()
    |> Enum.reduce_while({:ok, true}, fn condition, acc ->
      case evaluate_user_condition(condition, name, value, context) do
        {:ok, true} -> {:cont, acc}
        {:ok, false} -> {:halt, {:ok, false}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, in_segment?} ->
        {:ok, SegmentComparator.compare(comparator, in_segment?)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp evaluate_prerequisite_flag_condition(condition, %Context{} = context) do
    %Context{config: config, logs: logs, user: user, visited_keys: visited_keys} = context
    settings = Config.settings(config)
    prerequisite_key = PrerequisiteFlagCondition.prerequisite_flag_key(condition)
    comparator = PrerequisiteFlagCondition.comparator(condition)

    case Map.get(settings, prerequisite_key) do
      nil ->
        raise EvaluationError, "Prerequisite flag key is missing or invalid."

      setting ->
        setting_type = Setting.setting_type(setting)
        comparison_value_type = PrerequisiteFlagCondition.inferred_setting_type(condition)

        unless setting_type == comparison_value_type do
          raise EvaluationError,
                "Type mismatch between comparison value type #{SettingType.to_elixir_type(comparison_value_type)} and type #{SettingType.to_elixir_type(setting_type)} of prerequisite flag '#{prerequisite_key}'"
        end

        comparison_value = PrerequisiteFlagCondition.comparison_value(condition, setting_type)
        next_visited_keys = [context.key | visited_keys]

        if prerequisite_key in visited_keys do
          raise CircularDependencyError, prerequisite_key: prerequisite_key, visited_keys: next_visited_keys
        else
          %EvaluationDetails{value: prerequisite_value} =
            evaluate(prerequisite_key, user, nil, nil, config, logs, next_visited_keys)

          {:ok, PrerequisiteFlagComparator.compare(comparator, prerequisite_value, comparison_value)}
        end
    end
  end

  defp evaluate_percentage_options([] = _percentage_options, _context), do: {:none, nil, nil}

  defp evaluate_percentage_options(_percentage_options, %Context{user: nil} = context) do
    log_nil_user(context.key)
    {:none, nil, nil}
  end

  defp evaluate_percentage_options(percentage_options, %Context{} = context) do
    case extract_user_key(context) do
      {:ok, user_key} ->
        hash_val = hash_user(user_key, context.key)
        Enum.reduce_while(percentage_options, 0, &evaluate_percentage_option(&1, &2, hash_val, context))

      {:error, :missing_user_key} ->
        {:none, nil, nil}
    end
  end

  defp evaluate_percentage_option(option, increment, hash_val, %Context{} = context) do
    bucket = increment + PercentageOption.percentage(option)

    if hash_val < bucket do
      value = PercentageOption.value(option, context.setting_type)
      variation_id = PercentageOption.variation_id(option)

      {:halt, {value, variation_id, option}}
    else
      {:cont, bucket}
    end
  end

  defp extract_user_key(%Context{} = context) do
    attribute = context.percentage_option_attribute

    case User.get_attribute(context.user, attribute || "Identifier") do
      nil ->
        if is_nil(attribute) do
          {:ok, nil}
        else
          {:error, :missing_user_key}
        end

      value ->
        {:ok, value}
    end
  end

  defp hash_user(user_key, key) do
    hash_candidate = "#{key}#{user_key}"

    {hash_value, _} =
      :sha
      |> :crypto.hash(hash_candidate)
      |> Base.encode16()
      |> String.slice(0, 7)
      |> Integer.parse(16)

    rem(hash_value, 100)
  end

  defp base_value(setting, default_value, logs) do
    result = Setting.value(setting, default_value)

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

  defp log(nil, _message), do: :ok

  defp log(logs, message) do
    Agent.update(logs, &[message | &1])
  end
end
