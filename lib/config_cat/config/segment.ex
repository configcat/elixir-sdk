defmodule ConfigCat.Config.Segment do
  @moduledoc false
  alias ConfigCat.Config.ComparisonRule

  @type t :: %{String.t() => term()}

  @name "n"
  @segment_rules "r"

  @spec name(t()) :: String.t()
  def name(segment) do
    Map.get(segment, @name, "")
  end

  @spec segment_rules(t()) :: [ComparisonRule.t()]
  def segment_rules(segment) do
    Map.get(segment, @segment_rules, [])
  end
end
