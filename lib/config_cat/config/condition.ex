defmodule ConfigCat.Config.Condition do
  @moduledoc false
  alias ConfigCat.Config.ComparisonRule
  alias ConfigCat.Config.SegmentCondition

  @type t :: %{String.t() => term()}

  @segment_condition "s"
  @user_condition "u"

  @spec segment_condition(t()) :: SegmentCondition.t() | nil
  def segment_condition(condition) do
    Map.get(condition, @segment_condition)
  end

  @spec user_condition(t()) :: ComparisonRule.t() | nil
  def user_condition(condition) do
    Map.get(condition, @user_condition)
  end
end
