defmodule ConfigCat.Config.ComparisonRule do
  @moduledoc false
  alias ConfigCat.Config.UserComparator

  @type comparison_value :: number() | String.t() | [String.t()]
  @type t :: %{String.t() => term()}

  @comparator "c"
  @comparison_attribute "a"
  @double_value "d"
  @string_list_value "l"
  @string_value "s"

  @spec comparator(t()) :: UserComparator.t()
  def comparator(rule) do
    Map.fetch!(rule, @comparator)
  end

  @spec comparison_attribute(t()) :: String.t() | nil
  def comparison_attribute(rule) do
    Map.get(rule, @comparison_attribute)
  end

  @spec comparison_value(t()) :: comparison_value()
  def comparison_value(rule) do
    rule
    |> comparator()
    |> UserComparator.value_type()
    |> case do
      :double -> double_value(rule)
      :string -> string_value(rule)
      :string_list -> string_list_value(rule)
    end
  end

  defp double_value(rule) do
    Map.get(rule, @double_value)
  end

  defp string_list_value(rule) do
    rule
    |> Map.get(@string_list_value, [])
    |> Enum.map(&String.trim/1)
  end

  defp string_value(rule) do
    Map.get(rule, @string_value)
  end
end
