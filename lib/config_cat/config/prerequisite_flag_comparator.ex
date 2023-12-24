defmodule ConfigCat.Config.PrerequisiteFlagComparator do
  @moduledoc false
  alias ConfigCat.Config

  @type t :: non_neg_integer()

  @equals 0
  @not_equals 1

  @descriptions %{
    @equals => "EQUALS",
    @not_equals => "NOT EQUALS"
  }

  @spec compare(t(), Config.value(), Config.value()) :: boolean()
  def compare(@equals, prerequisite_value, comparison_value) do
    prerequisite_value == comparison_value
  end

  def compare(@not_equals, prerequisite_value, comparison_value) do
    prerequisite_value != comparison_value
  end

  @spec description(t()) :: String.t()
  def description(comparator) do
    Map.get(@descriptions, comparator, "Unsupported comparator")
  end
end
