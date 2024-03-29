defmodule ConfigCat.Config.Condition do
  @moduledoc false
  alias ConfigCat.Config.PrerequisiteFlagCondition
  alias ConfigCat.Config.Segment
  alias ConfigCat.Config.SegmentCondition
  alias ConfigCat.Config.UserCondition

  @type t :: %{String.t() => term()}

  @prerequisite_flag_condition "p"
  @segment_condition "s"
  @user_condition "u"

  @spec prerequisite_flag_condition(t()) :: PrerequisiteFlagCondition.t()
  def prerequisite_flag_condition(condition) do
    Map.get(condition, @prerequisite_flag_condition)
  end

  @spec segment_condition(t()) :: SegmentCondition.t() | nil
  def segment_condition(condition) do
    Map.get(condition, @segment_condition)
  end

  @spec user_condition(t()) :: UserCondition.t() | nil
  def user_condition(condition) do
    Map.get(condition, @user_condition)
  end

  @spec inline_segments(t(), [Segment.t()]) :: t()
  def inline_segments(condition, segments) do
    Map.update(condition, @segment_condition, nil, &SegmentCondition.inline_segment(&1, segments))
  end
end
