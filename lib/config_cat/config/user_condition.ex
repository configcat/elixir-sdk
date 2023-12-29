defmodule ConfigCat.Config.UserCondition do
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

  @spec fetch_comparison_attribute(t()) :: {:ok, String.t()} | {:error, :not_found}
  def fetch_comparison_attribute(rule) do
    case Map.fetch(rule, @comparison_attribute) do
      {:ok, attribute} -> {:ok, attribute}
      :error -> {:error, :not_found}
    end
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

  @spec description(t()) :: String.t()
  def description(condition) do
    attribute = comparison_attribute(condition)
    comparator = condition |> comparator() |> UserComparator.description()
    comparison_value = comparison_value(condition)

    # TODO: Truncate comparison value if needed
    "User.#{attribute} #{comparator} #{comparison_value}"
  end

  defp double_value(rule) do
    Map.get(rule, @double_value)
  end

  defp string_list_value(rule) do
    Map.get(rule, @string_list_value, [])
  end

  defp string_value(rule) do
    Map.get(rule, @string_value)
  end
end
