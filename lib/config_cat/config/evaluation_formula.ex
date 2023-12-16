defmodule ConfigCat.Config.EvaluationFormula do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.PercentageRule
  alias ConfigCat.Config.RolloutRule

  @type opt :: {:value, Config.value()}
  @type t :: %{String.t() => term()}

  @percentage_rules "p"
  @rollout_rules "r"
  @value "v"
  @variation_id "i"

  @spec new([opt]) :: t()
  def new(opts \\ []) do
    %{
      @value => opts[:value]
    }
  end

  @spec percentage_rules(t()) :: [PercentageRule.t()]
  def percentage_rules(formula) do
    Map.get(formula, @percentage_rules, [])
  end

  @spec rollout_rules(t()) :: [RolloutRule.t()]
  def rollout_rules(formula) do
    Map.get(formula, @rollout_rules, [])
  end

  @spec value(t()) :: Config.value()
  @spec value(t(), Config.value() | nil) :: Config.value() | nil
  def value(formula, default \\ nil) do
    Map.get(formula, @value, default)
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  @spec variation_id(t(), Config.variation_id() | nil) :: Config.variation_id() | nil
  def variation_id(formula, default \\ nil) do
    Map.get(formula, @variation_id, default)
  end
end
