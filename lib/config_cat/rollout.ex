defmodule ConfigCat.Rollout do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.Config.ComparisonContext
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
  alias ConfigCat.EvaluationLogger
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
      field :logger, pid() | nil
      field :percentage_option_attribute, String.t()
      field :salt, Config.salt()
      field :setting_type, SettingType.t()
      field :user, User.t(), enforce: false
      field :visited_keys, [String.t()]
    end
  end

  @default_percentage_option_attribute "Identifier"

  @spec evaluate(
          Config.key(),
          User.t() | nil,
          Config.value() | nil,
          Config.variation_id() | nil,
          Config.t(),
          pid() | nil,
          [String.t()]
        ) :: EvaluationDetails.t()
  # This function is slightly complex, but still reasonably understandable.
  # Breaking it up doesn't seem like it will help much.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def evaluate(key, user, default_value, default_variation_id, config, logger \\ nil, visited_keys \\ []) do
    root_flag_evaluation? = visited_keys == []
    settings = Config.settings(config)

    with {:ok, setting} <- setting(settings, key, default_value),
         {:ok, valid_user} <- validate_user(user) do
      percentage_options = Setting.percentage_options(setting)
      targeting_rules = Setting.targeting_rules(setting)

      context = %Context{
        config: config,
        key: key,
        logger: logger,
        percentage_option_attribute: Setting.percentage_option_attribute(setting) || @default_percentage_option_attribute,
        salt: Setting.salt(setting),
        setting_type: Setting.setting_type(setting),
        user: valid_user,
        visited_keys: visited_keys
      }

      try do
        if root_flag_evaluation? do
          logger
          |> EvaluationLogger.log_evaluating(key, context.user)
          |> EvaluationLogger.increase_indent()
        end

        case evaluate_rules(targeting_rules, percentage_options, context) do
          {:none, _variation_id, _matching_rule, _matching_option} ->
            value = Setting.value(setting, default_value)

            if root_flag_evaluation? do
              EvaluationLogger.log_return_value(logger, value)
            end

            EvaluationDetails.new(
              key: key,
              user: user,
              value: value,
              variation_id: Setting.variation_id(setting, default_variation_id)
            )

          {value, variation_id, rule, percentage_option} ->
            if root_flag_evaluation? do
              EvaluationLogger.log_return_value(logger, value)
            end

            EvaluationDetails.new(
              key: key,
              matched_targeting_rule: rule,
              matched_percentage_option: percentage_option,
              user: user,
              value: value,
              variation_id: variation_id || default_variation_id
            )
        end
      rescue
        error ->
          if root_flag_evaluation? do
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
    else
      {:error, :invalid_user} ->
        warn_invalid_user(key)
        evaluate(key, nil, default_value, default_variation_id, config, logger, visited_keys)

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

  defp evaluate_targeting_rules([], _context), do: {:none, nil, nil, nil}

  defp evaluate_targeting_rules(rules, %Context{} = context) do
    EvaluationLogger.log_evaluating_targeting_rules(context.logger)

    Enum.reduce_while(rules, {:none, nil, nil, nil}, fn rule, acc ->
      case evaluate_targeting_rule(rule, context) do
        {:none, _, _, _} -> {:cont, acc}
        result -> {:halt, result}
      end
    end)
  end

  defp evaluate_targeting_rule(rule, %Context{} = context) do
    %Context{logger: logger} = context
    conditions = TargetingRule.conditions(rule)
    value = TargetingRule.value(rule, context.setting_type)

    if evaluate_conditions(conditions, value, context) do
      case TargetingRule.simple_value(rule) do
        nil ->
          EvaluationLogger.increase_indent(logger)
          percentage_options = TargetingRule.percentage_options(rule)
          {value, variation_id, option} = evaluate_percentage_options(percentage_options, context)

          if value == :none do
            EvaluationLogger.log_ignored_targeting_rule(logger)
          end

          EvaluationLogger.decrease_indent(logger)
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
    condition_count = length(conditions)

    result =
      conditions
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, true}, fn {condition, index}, acc ->
        EvaluationLogger.log_evaluating_condition_start(context.logger, index)

        case evaluate_condition(condition, condition_count, context) do
          {:ok, true} -> {:cont, acc}
          result -> {:halt, result}
        end
      end)

    EvaluationLogger.log_evaluating_condition_result(context.logger, result, condition_count, value)

    case result do
      {:ok, result} -> result
      {:error, _error} -> false
    end
  end

  defp evaluate_condition(condition, condition_count, %Context{} = context) do
    %Context{logger: logger} = context
    prerequisite_flag_condition = Condition.prerequisite_flag_condition(condition)
    segment_condition = Condition.segment_condition(condition)
    user_condition = Condition.user_condition(condition)

    cond do
      user_condition ->
        result = evaluate_user_condition(user_condition, context.key, context)
        EvaluationLogger.log_evaluating_user_condition_result(logger, result, condition_count)
        result

      segment_condition ->
        result = evaluate_segment_condition(segment_condition, context)
        EvaluationLogger.log_evaluating_segment_condition_final_result(logger, result, condition_count)
        result

      prerequisite_flag_condition ->
        evaluate_prerequisite_flag_condition(prerequisite_flag_condition, context)

      true ->
        {:ok, true}
    end
  end

  defp evaluate_user_condition(condition, _context_salt, %Context{user: nil} = context) do
    EvaluationLogger.log_evaluating_user_condition_start(context.logger, condition)
    warn_missing_user(context.key)
    {:error, "cannot evaluate, User Object is missing"}
  end

  defp evaluate_user_condition(condition, context_salt, %Context{} = context) do
    %Context{key: key, logger: logger, salt: salt, user: user} = context

    EvaluationLogger.log_evaluating_user_condition_start(logger, condition)

    case UserCondition.fetch_comparison_attribute(condition) do
      {:error, :not_found} ->
        raise EvaluationError, "Comparison attribute name missing"

      {:ok, comparison_attribute} ->
        comparator = UserCondition.comparator(condition)
        comparison_value = UserCondition.comparison_value(condition)

        case User.get_attribute(user, comparison_attribute) do
          nil ->
            warn_missing_user_attribute(context.key, condition, comparison_attribute)
            {:error, "cannot evaluate, the User.#{comparison_attribute} attribute is missing"}

          user_value ->
            context = %ComparisonContext{
              condition: condition,
              context_salt: context_salt,
              key: key,
              salt: salt
            }

            case UserComparator.compare(comparator, user_value, comparison_value, context) do
              {:ok, result} ->
                {:ok, result}

              {:error, :invalid_datetime} ->
                message = "'#{user_value}' is not a valid Unix timestamp (number of seconds elapsed since Unix epoch)"
                handle_invalid_user_attribute(key, condition, message)

              {:error, :invalid_float} ->
                message = "'#{user_value}' is not a valid decimal number"
                handle_invalid_user_attribute(key, condition, message)

              {:error, :invalid_string_list} ->
                message = "'#{user_value}' is not a valid string array"
                handle_invalid_user_attribute(key, condition, message)

              {:error, :invalid_version} ->
                trimmed = user_value |> to_string() |> String.trim()
                message = "'#{trimmed}' is not a valid semantic version"
                handle_invalid_user_attribute(key, condition, message)
            end
        end
    end
  end

  defp evaluate_segment_condition(condition, %Context{user: nil} = context) do
    warn_missing_user(context.key)
    EvaluationLogger.log_skipping_segment_condition_missing_user(context.logger, condition)
    {:error, "cannot evaluate, User Object is missing"}
  end

  defp evaluate_segment_condition(condition, %Context{} = context) do
    %Context{logger: logger} = context

    case SegmentCondition.fetch_segment(condition) do
      {:error, :not_found} ->
        raise EvaluationError, "Segment reference is invalid."

      {:ok, segment} ->
        comparator = SegmentCondition.segment_comparator(condition)
        name = Segment.name(segment)

        EvaluationLogger.log_evaluating_segment_condition_start(logger, condition, name)

        segment
        |> Segment.conditions()
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, true}, fn {condition, index}, acc ->
          EvaluationLogger.log_evaluating_condition_start(logger, index)

          result = evaluate_user_condition(condition, name, context)
          # Faking multiple conditions; may want to use actual condition count
          # eventually. Keeping it this way to match Python SDK for now.
          EvaluationLogger.log_evaluating_user_condition_result(logger, result, 2)

          case result do
            {:ok, true} -> {:cont, acc}
            {:ok, false} -> {:halt, {:ok, false}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)
        |> case do
          {:ok, in_segment?} ->
            result = {:ok, SegmentComparator.compare(comparator, in_segment?)}
            EvaluationLogger.log_evaluating_segment_condition_result(logger, condition, in_segment?, result)
            result

          {:error, _error} = result ->
            EvaluationLogger.log_evaluating_segment_condition_result(logger, condition, false, result)
            result
        end
    end
  end

  defp evaluate_prerequisite_flag_condition(condition, %Context{} = context) do
    %Context{config: config, logger: logger, user: user, visited_keys: visited_keys} = context
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
          EvaluationLogger.log_evaluating_prerequisite_condition_start(logger, condition, setting_type)

          %EvaluationDetails{value: prerequisite_value} =
            evaluate(prerequisite_key, user, nil, nil, config, logger, next_visited_keys)

          result = PrerequisiteFlagComparator.compare(comparator, prerequisite_value, comparison_value)

          EvaluationLogger.log_evaluating_prerequisite_condition_result(
            logger,
            condition,
            setting_type,
            prerequisite_value,
            result
          )

          {:ok, result}
        end
    end
  end

  defp evaluate_percentage_options([] = _percentage_options, _context), do: {:none, nil, nil}

  defp evaluate_percentage_options(_percentage_options, %Context{user: nil} = context) do
    warn_missing_user(context.key)
    EvaluationLogger.log_skipping_percentage_options_missing_user(context.logger)
    {:none, nil, nil}
  end

  defp evaluate_percentage_options(percentage_options, %Context{} = context) do
    case extract_user_key(context) do
      {:ok, user_key} ->
        hash_val = hash_user(user_key, context.key)
        Enum.reduce_while(percentage_options, {0, 1}, &evaluate_percentage_option(&1, &2, hash_val, context))

      {:error, :missing_user_key} ->
        attribute_name = context.percentage_option_attribute
        warn_missing_user_attribute(context.key, attribute_name)
        EvaluationLogger.log_skipping_percentage_options_missing_user_attribute(context.logger, attribute_name)
        {:none, nil, nil}
    end
  end

  defp evaluate_percentage_option(option, increment, hash_val, %Context{} = context) do
    percentage = PercentageOption.percentage(option)
    {last_bucket, index} = increment
    bucket = last_bucket + percentage

    if hash_val < bucket do
      value = PercentageOption.value(option, context.setting_type)
      variation_id = PercentageOption.variation_id(option)
      attribute_name = context.percentage_option_attribute

      EvaluationLogger.log_matching_percentage_option(context.logger, attribute_name, hash_val, index, percentage, value)

      {:halt, {value, variation_id, option}}
    else
      {:cont, {bucket, index + 1}}
    end
  end

  defp extract_user_key(%Context{} = context) do
    attribute = context.percentage_option_attribute

    case User.get_attribute(context.user, attribute) do
      nil ->
        if attribute == @default_percentage_option_attribute do
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

  defp handle_invalid_user_attribute(key, condition, message) do
    warn_type_mismatch(key, condition, message)

    attribute = UserCondition.comparison_attribute(condition)
    {:error, "cannot evaluate, the User.#{attribute} attribute is invalid (#{message})"}
  end

  defp warn_invalid_user(key) do
    ConfigCatLogger.warning(
      "Cannot evaluate targeting rules and % options for setting '#{key}' " <>
        "(User Object is not an instance of `ConfigCat.User` struct)." <>
        "You should pass a User Object to the evaluation functions like `get_value()` " <>
        "in order to make targeting work properly. " <>
        "Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 4001
    )
  end

  defp warn_missing_user(key) do
    ConfigCatLogger.warning(
      "Cannot evaluate targeting rules and % options for setting '#{key}' " <>
        "(User Object is missing). " <>
        "You should pass a User Object to the evaluation functions like `get_value()` " <>
        "in order to make targeting work properly. " <>
        "Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3001
    )
  end

  defp warn_missing_user_attribute(key, attribute_name) do
    ConfigCatLogger.warning(
      "Cannot evaluate % options for setting '#{key}' " <>
        "(the User.#{attribute_name} attribute is missing). You should set the User.#{attribute_name} attribute in order to make " <>
        "targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3003
    )
  end

  defp warn_missing_user_attribute(key, user_condition, attribute_name) do
    ConfigCatLogger.warning(
      "Cannot evaluate condition (#{UserCondition.description(user_condition)}) for setting '#{key}' " <>
        "(the User.#{attribute_name} attribute is missing). You should set the User.#{attribute_name} attribute in order to make " <>
        "targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3003
    )
  end

  defp warn_type_mismatch(key, condition, message) do
    attribute = UserCondition.comparison_attribute(condition)
    condition_text = UserCondition.description(condition)

    ConfigCatLogger.warning(
      "Cannot evaluate condition (#{condition_text}) for setting '#{key}' " <>
        "(#{message}). Please check the User.#{attribute} attribute and make sure that its value corresponds to the " <>
        "comparison operator.",
      event_id: 3004
    )
  end
end
