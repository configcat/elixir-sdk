defmodule ConfigCat.EvaluationLogger do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.PrerequisiteFlagCondition
  alias ConfigCat.Config.SegmentCondition
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.UserCondition
  alias ConfigCat.User

  @type t :: Agent.agent()
  @typep condition_result :: {:ok, boolean()} | {:error, String.t()}

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :indent_level, non_neg_integer(), default: 0
      field :lines, [String.t()], default: []
    end

    @spec append(t(), String.t()) :: t()
    def append(%__MODULE__{} = state, text) do
      [first | rest] = state.lines
      %{state | lines: [first <> text | rest]}
    end

    @spec decrease_indent(t()) :: t()
    def decrease_indent(%__MODULE__{} = state) do
      %{state | indent_level: max(0, state.indent_level - 1)}
    end

    @spec increase_indent(t()) :: t()
    def increase_indent(%__MODULE__{} = state) do
      %{state | indent_level: state.indent_level + 1}
    end

    @spec new_line(t(), String.t()) :: t()
    def new_line(%__MODULE__{} = state, text) do
      line = String.duplicate("  ", state.indent_level) <> text
      %{state | lines: [line | state.lines]}
    end

    @spec result(t()) :: String.t()
    def result(%__MODULE__{} = state) do
      state.lines
      |> Enum.reverse()
      |> Enum.join("\n")
    end
  end

  @spec start :: Agent.on_start()
  def start do
    Agent.start(fn -> %State{} end)
  end

  @spec stop(t() | nil) :: :ok
  def stop(nil), do: :ok

  def stop(logger) do
    Agent.stop(logger)
  end

  @spec decrease_indent(t() | nil) :: t() | nil
  def decrease_indent(nil), do: nil

  def decrease_indent(logger) do
    Agent.update(logger, &State.decrease_indent/1)
    logger
  end

  @spec increase_indent(t() | nil) :: t() | nil
  def increase_indent(nil), do: nil

  def increase_indent(logger) do
    Agent.update(logger, &State.increase_indent/1)
    logger
  end

  @spec log_evaluating(t() | nil, Config.key(), User.t() | nil) :: t() | nil
  def log_evaluating(nil, _key, _user), do: nil

  def log_evaluating(logger, key, user) do
    new_line(logger, "Evaluating '#{key}'")

    if user do
      append(logger, " for User '#{user}'")
    end

    logger
  end

  @spec log_evaluating_condition_final_result(t() | nil, condition_result(), boolean(), Config.value() | nil) ::
          t() | nil
  def log_evaluating_condition_final_result(nil, _result, _newline?, _value), do: nil

  def log_evaluating_condition_final_result(logger, result, newline?, value) do
    increase_indent(logger)
    if newline?, do: new_line(logger), else: append(logger, " ")

    formatted_value = if value, do: "'#{value}'", else: "% options"
    append(logger, "THEN #{formatted_value} => ")

    case result do
      {:ok, condition_result} ->
        formatted_result = if condition_result, do: "MATCH, applying rule", else: "no match"
        append(logger, formatted_result)

      {:error, error} ->
        logger
        |> append(error)
        |> new_line("The current targeting rule is ignored and the evaluation continues with the next rule.")
    end

    decrease_indent(logger)
  end

  @spec log_evaluating_condition_result(t() | nil, condition_result()) :: t() | nil
  def log_evaluating_condition_result(nil, _result), do: nil

  def log_evaluating_condition_result(logger, result) do
    case result do
      {:ok, true} -> append(logger, " => true")
      _ -> append(logger, " => false, skipping the remaining AND conditions")
    end
  end

  @spec log_evaluating_condition_start(t() | nil, non_neg_integer()) :: t() | nil
  def log_evaluating_condition_start(nil, _index), do: nil

  def log_evaluating_condition_start(logger, index) do
    if index == 0 do
      logger
      |> new_line("- IF ")
      |> increase_indent()
    else
      logger
      |> increase_indent()
      |> new_line("AND ")
    end
  end

  @spec log_evaluating_prerequisite_condition_result(
          t() | nil,
          PrerequisiteFlagCondition.t(),
          SettingType.t(),
          Config.value(),
          boolean()
        ) ::
          t() | nil
  def log_evaluating_prerequisite_condition_result(nil, _condition, _setting_type, _value, _result), do: nil

  def log_evaluating_prerequisite_condition_result(logger, condition, setting_type, value, result) do
    logger
    |> new_line("Prerequisite flag evaluation result: '#{value}'.")
    |> new_line("Condition (#{PrerequisiteFlagCondition.description(condition, setting_type)}) evaluates to #{result}.")
    |> decrease_indent()
    |> new_line(")")
  end

  @spec log_evaluating_prerequisite_condition_start(t() | nil, PrerequisiteFlagCondition.t(), SettingType.t()) ::
          t() | nil
  def log_evaluating_prerequisite_condition_start(nil, _condition, _setting_type), do: nil

  def log_evaluating_prerequisite_condition_start(logger, condition, setting_type) do
    key = PrerequisiteFlagCondition.prerequisite_flag_key(condition)

    logger
    |> append(PrerequisiteFlagCondition.description(condition, setting_type))
    |> new_line("(")
    |> increase_indent()
    |> new_line("Evaluating prerequisite flag '#{key}':")
  end

  @spec log_evaluating_segment_condition_result(t() | nil, SegmentCondition.t(), boolean(), condition_result()) ::
          t() | nil
  def log_evaluating_segment_condition_result(nil, _condition, _in_segment?, _result), do: nil

  def log_evaluating_segment_condition_result(logger, condition, in_segment?, result) do
    description = SegmentCondition.description(condition)

    logger
    |> decrease_indent()
    |> new_line("Segment evaluation result: ")

    case result do
      {:ok, match?} ->
        maybe_not = if in_segment?, do: " ", else: " NOT "

        logger
        |> append("User IS#{maybe_not}IN SEGMENT.")
        |> new_line("Condition (#{description}) ")
        |> append("evaluates to #{match?}.")
        |> decrease_indent()
        |> new_line(")")

      {:error, error} ->
        logger
        |> append("#{error}.")
        |> new_line("Condition (#{description}) ")
        |> append("failed to evaluate.")
        |> decrease_indent()
        |> new_line(")")
    end
  end

  @spec log_evaluating_segment_condition_start(t() | nil, SegmentCondition.t(), String.t()) :: t() | nil
  def log_evaluating_segment_condition_start(nil, _condition, _segment_name), do: nil

  def log_evaluating_segment_condition_start(logger, condition, segment_name) do
    logger
    |> append("#{SegmentCondition.description(condition)}")
    |> new_line("(")
    |> increase_indent()
    |> new_line("Evaluating segment '#{segment_name}':")
  end

  @spec log_evaluating_targeting_rules(t() | nil) :: t() | nil
  def log_evaluating_targeting_rules(nil), do: nil

  def log_evaluating_targeting_rules(logger) do
    new_line(logger, "Evaluating targeting rules and applying the first match if any:")
  end

  @spec log_evaluating_user_condition_start(t() | nil, UserCondition.t()) :: t() | nil
  def log_evaluating_user_condition_start(nil, _condition), do: nil

  def log_evaluating_user_condition_start(logger, condition) do
    append(logger, "#{UserCondition.description(condition)}")
  end

  @spec log_ignored_targeting_rule(t() | nil) :: t() | nil
  def log_ignored_targeting_rule(nil), do: nil

  def log_ignored_targeting_rule(logger) do
    new_line(logger, "The current targeting rule is ignored and the evaluation continues with the next rule.")
  end

  @spec log_matching_percentage_option(
          t() | nil,
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Config.value()
        ) :: t()
  def log_matching_percentage_option(nil, _attribute_name, _hash_value, _index, _percentage, _value), do: nil

  def log_matching_percentage_option(logger, attribute_name, hash_value, index, percentage, value) do
    logger
    |> new_line("Evaluating % options based on the User.#{attribute_name} attribute:")
    |> new_line(
      "- Computing hash in the [0..99] range from User.#{attribute_name} => #{hash_value} " <>
        "(this value is sticky and consistent across all SDKs)"
    )
    |> new_line("- Hash value #{hash_value} selects % option #{index} (#{percentage}%), '#{value}'.")
  end

  @spec log_return_value(t() | nil, Config.value()) :: t() | nil
  def log_return_value(nil, _value), do: nil

  def log_return_value(logger, value) do
    new_line(logger, "Returning '#{value}'.")
  end

  @spec log_skipping_percentage_options_missing_user(t() | nil) :: t() | nil
  def log_skipping_percentage_options_missing_user(nil), do: nil

  def log_skipping_percentage_options_missing_user(logger) do
    new_line(logger, "Skipping % options because the User Object is missing.")
  end

  @spec log_skipping_percentage_options_missing_user_attribute(t() | nil, String.t()) :: t() | nil
  def log_skipping_percentage_options_missing_user_attribute(nil, _attribute_name), do: nil

  def log_skipping_percentage_options_missing_user_attribute(logger, attribute_name) do
    new_line(logger, "Skipping % options because the User.#{attribute_name} attribute is missing.")
  end

  @spec log_skipping_segment_condition_missing_user(t() | nil, SegmentCondition.t()) :: t() | nil
  def log_skipping_segment_condition_missing_user(nil, _condition), do: nil

  def log_skipping_segment_condition_missing_user(logger, condition) do
    append(logger, "#{SegmentCondition.description(condition)}")
  end

  @spec result(t() | nil) :: String.t()
  def result(nil), do: ""

  def result(logger) do
    Agent.get(logger, &State.result/1)
  end

  defp append(logger, text) do
    Agent.update(logger, &State.append(&1, text))
    logger
  end

  defp new_line(logger, text \\ "") do
    Agent.update(logger, &State.new_line(&1, text))
    logger
  end
end
