defmodule ConfigCat.Config.PercentageOption do
  @moduledoc false
  alias ConfigCat.Config

  @type t :: %{String.t() => term()}

  @percentage "p"
  @value "v"
  @variation_id "i"

  @spec percentage(t()) :: non_neg_integer()
  def percentage(rule) do
    Map.get(rule, @percentage, 0)
  end

  @spec value(t()) :: Config.value()
  def value(rule) do
    Map.get(rule, @value)
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  def variation_id(rule) do
    Map.get(rule, @variation_id)
  end

  @spec variation_value(t(), Config.variation_id()) :: Config.value() | nil
  def variation_value(rule, variation_id) do
    if variation_id(rule) == variation_id do
      value(rule)
    end
  end
end
