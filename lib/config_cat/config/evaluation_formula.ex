defmodule ConfigCat.Config.EvaluationFormula do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.PercentageOption
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.TargetingRule
  alias ConfigCat.Config.Value

  @type opt :: {:setting_type, SettingType.t()} | {:value, Config.value()}
  @type t :: %{String.t() => term()}

  @percentage_options "p"
  @setting_type "t"
  @targeting_rules "r"
  @value "v"
  @variation_id "i"

  @spec new([opt]) :: t()
  def new(opts \\ []) do
    case opts[:value] do
      nil ->
        %{@value => nil}

      value ->
        setting_type = SettingType.from_value(value)

        %{
          @setting_type => setting_type,
          @value => Value.new(value, setting_type)
        }
    end
  end

  @spec percentage_options(t()) :: [PercentageOption.t()]
  def percentage_options(formula) do
    Map.get(formula, @percentage_options, [])
  end

  @spec setting_type(t()) :: SettingType.t() | nil
  def setting_type(formula) do
    Map.get(formula, @setting_type)
  end

  @spec targeting_rules(t()) :: [TargetingRule.t()]
  def targeting_rules(formula) do
    Map.get(formula, @targeting_rules, [])
  end

  @spec value(t()) :: Config.value()
  @spec value(t(), Config.value() | nil) :: Config.value()
  def value(formula, default \\ nil) do
    case Map.get(formula, @value) do
      nil -> default
      value -> Value.get(value, setting_type(formula), default)
    end
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  @spec variation_id(t(), Config.variation_id() | nil) :: Config.variation_id() | nil
  def variation_id(formula, default \\ nil) do
    Map.get(formula, @variation_id, default)
  end

  @spec variation_value(t(), Config.variation_id()) :: Config.value() | nil
  def variation_value(formula, variation_id) do
    if variation_id(formula) == variation_id do
      value(formula)
    else
      targeting_value = targeting_rule_variation_value(formula, variation_id)

      if is_nil(targeting_value) do
        percentage_rule_variation_value(formula, variation_id)
      else
        targeting_value
      end
    end
  end

  defp targeting_rule_variation_value(formula, variation_id) do
    formula
    |> targeting_rules()
    |> Enum.find_value(nil, &TargetingRule.variation_value(&1, variation_id))
  end

  defp percentage_rule_variation_value(formula, variation_id) do
    formula
    |> percentage_options()
    |> Enum.find_value(nil, &PercentageOption.variation_value(&1, variation_id))
  end
end
