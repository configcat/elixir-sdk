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
    case Map.get(condition, @comparison_value) do
      nil -> nil
      value -> Value.get(value, setting_type, nil)
    end
  end

  @spec prerequisite_flag_key(t()) :: String.t()
  def prerequisite_flag_key(condition) do
    Map.fetch!(condition, @prerequisite_flag_key)
  end
end
