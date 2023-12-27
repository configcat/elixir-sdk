defmodule ConfigCat.Config.SegmentCondition do
  @moduledoc false
  alias ConfigCat.Config.SegmentComparator

  @type t :: %{String.t() => any}

  @inline_segment "inline_segment"
  @segment_comparator "c"
  @segment_index "s"

  @spec segment(t()) :: Segment.t() | nil
  def segment(condition) do
    Map.get(condition, @inline_segment)
  end

  @spec segment_comparator(t()) :: SegmentComparator.t() | nil
  def segment_comparator(condition) do
    Map.get(condition, @segment_comparator)
  end

  @spec segment_index(t()) :: non_neg_integer() | nil
  def segment_index(condition) do
    Map.get(condition, @segment_index)
  end
end
