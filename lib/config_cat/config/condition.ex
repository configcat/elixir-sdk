defmodule ConfigCat.Config.Condition do
  @moduledoc false
  alias ConfigCat.Config.ComparisonRule

  @type t :: %{String.t() => term()}

  @user_condition "u"

  @spec user_condition(t()) :: ComparisonRule.t() | nil
  def user_condition(condition) do
    Map.get(condition, @user_condition)
  end
end
