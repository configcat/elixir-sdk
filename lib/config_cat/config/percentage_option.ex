defmodule ConfigCat.Config.PercentageOption do
  @moduledoc false
  alias ConfigCat.Config.ValueAndVariationId

  @type t :: %{String.t() => term()}

  @percentage "p"

  @spec percentage(t()) :: non_neg_integer()
  def percentage(option) do
    Map.get(option, @percentage, 0)
  end

  defdelegate value(option, setting_type, default \\ nil), to: ValueAndVariationId
  defdelegate variation_id(option, default \\ nil), to: ValueAndVariationId
  defdelegate variation_value(option, variation_id), to: ValueAndVariationId
end
