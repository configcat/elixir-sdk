defmodule ConfigCat.Config.PrerequisiteFlagCondition do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.PrerequisiteFlagComparator
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.Value

  @type t :: %{String.t() => term()}

  @comparator "c"
  @comparison_value "v"
  @prerequisite_flag_key "f"

  @spec comparator(t()) :: PrerequisiteFlagComparator.t()
  def comparator(condition) do
    Map.fetch!(condition, @comparator)
  end

  @spec comparison_value(t(), SettingType.t()) :: Config.value() | nil
  def comparison_value(condition, setting_type) do
    case raw_value(condition) do
      nil -> nil
      value -> Value.get(value, setting_type, nil)
    end
  end

  @spec prerequisite_flag_key(t()) :: String.t()
  def prerequisite_flag_key(condition) do
    Map.fetch!(condition, @prerequisite_flag_key)
  end

  @spec inferred_setting_type(t()) :: SettingType.t() | nil
  def inferred_setting_type(condition) do
    case raw_value(condition) do
      nil -> nil
      value -> Value.inferred_setting_type(value)
    end
  end

  defp raw_value(condition) do
    Map.get(condition, @comparison_value)
  end
end
