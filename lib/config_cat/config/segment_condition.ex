defmodule ConfigCat.Config.SegmentCondition do
  @moduledoc false
  alias ConfigCat.Config.Segment
  alias ConfigCat.Config.SegmentComparator

  @type t :: %{String.t() => any}

  @inline_segment "inline_segment"
  @segment_comparator "c"
  @segment_index "s"

  @spec segment(t()) :: Segment.t()
  def segment(condition) do
    Map.get(condition, @inline_segment, %{})
  end

  @spec fetch_segment(t()) :: {:ok, Segment.t()} | {:error, :not_found}
  def fetch_segment(condition) do
    case Map.fetch(condition, @inline_segment) do
      {:ok, segment} -> {:ok, segment}
      :error -> {:error, :not_found}
    end
  end

  @spec segment_comparator(t()) :: SegmentComparator.t() | nil
  def segment_comparator(condition) do
    Map.get(condition, @segment_comparator)
  end

  @spec segment_index(t()) :: non_neg_integer() | nil
  def segment_index(condition) do
    Map.get(condition, @segment_index)
  end

  @spec inline_segment(t(), [Segment.t()]) :: t()
  def inline_segment(condition, segments) do
    index = segment_index(condition)
    segment = Enum.at(segments, index)
    Map.put(condition, @inline_segment, segment)
  end

  @spec description(t()) :: String.t()
  def description(condition) do
    comparator = segment_comparator(condition)
    segment_name = condition |> segment() |> Segment.name()

    "User #{SegmentComparator.description(comparator)} '#{segment_name}'"
  end
end
