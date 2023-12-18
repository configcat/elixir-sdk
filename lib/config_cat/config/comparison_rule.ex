defmodule ConfigCat.Config.ComparisonRule do
  @moduledoc false
  alias ConfigCat.Config

  @type t :: %{String.t() => term()}

  @comparator "c"
  @comparison_attribute "a"
  @string_value "s"

  @spec comparator(t()) :: Config.comparator() | nil
  def comparator(rule) do
    Map.get(rule, @comparator)
  end

  @spec comparison_attribute(t()) :: String.t() | nil
  def comparison_attribute(rule) do
    Map.get(rule, @comparison_attribute)
  end

  @spec string_value(t()) :: String.t() | nil
  def string_value(rule) do
    Map.get(rule, @string_value)
  end
end
