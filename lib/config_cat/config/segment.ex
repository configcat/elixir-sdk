defmodule ConfigCat.Config.Segment do
  @moduledoc false
  alias ConfigCat.Config.UserCondition

  @type t :: %{String.t() => term()}

  @conditions "r"
  @name "n"

  @spec conditions(t()) :: [UserCondition.t()]
  def conditions(segment) do
    Map.get(segment, @conditions, [])
  end

  @spec name(t()) :: String.t()
  def name(segment) do
    Map.get(segment, @name, "")
  end
end
