defmodule ConfigCat.Config.TargetingRule do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.Condition
  alias ConfigCat.Config.PercentageOption
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.ValueAndVariationId

  @type t :: %{String.t() => term()}

  @conditions "c"
  @percentage_options "p"
  @served_value "s"

  @spec conditions(t()) :: [Condition.t()]
  def conditions(rule) do
    Map.get(rule, @conditions, [])
  end

  @spec percentage_options(t()) :: [PercentageOption.t()]
  def percentage_options(rule) do
    Map.get(rule, @percentage_options, [])
  end

  @spec served_value(t()) :: ValueAndVariationId.t() | nil
  def served_value(rule) do
    Map.get(rule, @served_value)
  end

  @spec value(t(), SettingType.t()) :: Config.value()
  @spec value(t(), SettingType.t(), Config.value() | nil) :: Config.value()
  def value(rule, setting_type, default \\ nil) do
    case served_value(rule) do
      nil -> default
      value -> ValueAndVariationId.value(value, setting_type, default)
    end
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  @spec variation_id(t(), Config.variation_id() | nil) :: Config.variation_id() | nil
  def variation_id(rule, default \\ nil) do
    case served_value(rule) do
      nil -> default
      value -> ValueAndVariationId.variation_id(value, default)
    end
  end

  @spec variation_value(t(), Config.variation_id()) :: Config.value() | nil
  def variation_value(rule, variation_id) do
    case served_value(rule) do
      nil -> nil
      value -> ValueAndVariationId.variation_value(value, variation_id)
    end
  end
end
