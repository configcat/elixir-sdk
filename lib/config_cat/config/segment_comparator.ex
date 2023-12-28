defmodule ConfigCat.Config.SegmentComparator do
  @moduledoc false

  @type t :: non_neg_integer()

  @is_in 0
  @is_not_in 1

  @descriptions %{
    @is_in => "IS IN SEGMENT",
    @is_not_in => "IS NOT IN SEGMENT"
  }

  @spec compare(t(), boolean()) :: boolean()
  def compare(@is_in, in_segment?), do: in_segment?
  def compare(@is_not_in, in_segment?), do: not in_segment?
  def compare(_invalid_comparator, _in_segment?), do: false

  @spec description(t()) :: String.t()
  def description(comparator) do
    Map.get(@descriptions, comparator, "Unsupported comparator")
  end
end
