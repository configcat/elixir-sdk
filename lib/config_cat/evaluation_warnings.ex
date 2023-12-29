defmodule ConfigCat.EvaluationWarnings do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.UserCondition

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @type t :: Agent.agent()

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :warned_missing_or_invalid_user?, boolean(), default: false
    end

    @spec note_warned_missing_or_invalid_user(t()) :: t()
    def note_warned_missing_or_invalid_user(%__MODULE__{} = state) do
      %{state | warned_missing_or_invalid_user?: true}
    end
  end

  @spec start :: Agent.on_start()
  def start do
    Agent.start(fn -> %State{} end)
  end

  @spec stop(t()) :: :ok
  def stop(warnings) do
    Agent.stop(warnings)
  end

  @spec warn_invalid_user(t(), Config.key()) :: :ok
  def warn_invalid_user(warnings, key) do
    if warned_missing_or_invalid_user?(warnings) do
      :ok
    else
      ConfigCatLogger.warning(
        "Cannot evaluate targeting rules and % options for setting '#{key}' " <>
          "(User Object is not an instance of `ConfigCat.User` struct)." <>
          "You should pass a User Object to the evaluation functions like `get_value()` " <>
          "in order to make targeting work properly. " <>
          "Read more: https://configcat.com/docs/advanced/user-object/",
        event_id: 4001
      )

      note_warned_missing_or_invalid_user(warnings)
    end
  end

  @spec warn_missing_user(t(), Config.key()) :: :ok
  def warn_missing_user(warnings, key) do
    if warned_missing_or_invalid_user?(warnings) do
      :ok
    else
      ConfigCatLogger.warning(
        "Cannot evaluate targeting rules and % options for setting '#{key}' " <>
          "(User Object is missing). " <>
          "You should pass a User Object to the evaluation functions like `get_value()` " <>
          "in order to make targeting work properly. " <>
          "Read more: https://configcat.com/docs/advanced/user-object/",
        event_id: 3001
      )

      note_warned_missing_or_invalid_user(warnings)
    end
  end

  @spec warn_missing_user_attribute(t(), Config.key(), String.t()) :: :ok
  def warn_missing_user_attribute(_warnings, key, attribute_name) do
    ConfigCatLogger.warning(
      "Cannot evaluate % options for setting '#{key}' " <>
        "(the User.#{attribute_name} attribute is missing). You should set the User.#{attribute_name} attribute in order to make " <>
        "targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3003
    )
  end

  @spec warn_missing_user_attribute(t(), Config.key(), UserCondition.t(), String.t()) :: :ok
  def warn_missing_user_attribute(_warnings, key, user_condition, attribute_name) do
    ConfigCatLogger.warning(
      "Cannot evaluate condition (#{UserCondition.description(user_condition)}) for setting '#{key}' " <>
        "(the User.#{attribute_name} attribute is missing). You should set the User.#{attribute_name} attribute in order to make " <>
        "targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/",
      event_id: 3003
    )
  end

  @spec warn_type_mismatch(t(), Config.key(), UserCondition.t(), String.t()) :: :ok
  def warn_type_mismatch(_warnings, key, condition, message) do
    attribute = UserCondition.comparison_attribute(condition)
    condition_text = UserCondition.description(condition)

    ConfigCatLogger.warning(
      "Cannot evaluate condition (#{condition_text}) for setting '#{key}' " <>
        "(#{message}). Please check the User.#{attribute} attribute and make sure that its value corresponds to the " <>
        "comparison operator.",
      event_id: 3004
    )
  end

  defp note_warned_missing_or_invalid_user(warnings) do
    Agent.update(warnings, &State.note_warned_missing_or_invalid_user/1)
  end

  defp warned_missing_or_invalid_user?(warnings) do
    Agent.get(warnings, fn %State{} = state -> state.warned_missing_or_invalid_user? end)
  end
end
