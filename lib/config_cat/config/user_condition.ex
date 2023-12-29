defmodule ConfigCat.Config.UserCondition do
  @moduledoc false
  import ConfigCat.Config.UserComparator, only: [is_for_datetime: 1, is_for_hashed: 1]

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
    comparator = comparator(condition)
    comparator_text = UserComparator.description(comparator)
    comparison_value = comparison_value(condition)

    "User.#{attribute} #{comparator_text} #{format_comparison_value(comparison_value, comparator)}"
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

  defp format_comparison_value(values, comparator) when length(values) > 1 and is_for_hashed(comparator) do
    "[<#{length(values)} hashed values>]"
  end

  defp format_comparison_value(values, comparator) when is_list(values) and is_for_hashed(comparator) do
    "[<#{length(values)} hashed value>]"
  end

  defp format_comparison_value(_value, comparator) when is_for_hashed(comparator) do
    "'<hashed value>'"
  end

  @length_limit 10
  defp format_comparison_value(values, _comparator) when is_list(values) do
    length = length(values)

    if length > @length_limit do
      remaining = length - @length_limit
      more_text = if remaining == 1, do: "<1 more value>", else: "<#{remaining} more values>"
      entries = values |> Enum.take(@length_limit) |> format_list_entries()
      "[#{entries}, ... #{more_text}]"
    else
      "[#{format_list_entries(values)}]"
    end
  end

  defp format_comparison_value(value, comparator) when is_for_datetime(comparator) do
    formatted =
      (value * 1000)
      |> round()
      |> DateTime.from_unix!(:millisecond)
      |> DateTime.truncate(:millisecond)
      |> DateTime.to_iso8601()

    "'#{value}' (#{formatted} UTC)"
  end

  defp format_comparison_value(value, _comparator) do
    "'#{value}'"
  end

  defp format_list_entries(values) do
    Enum.map_join(values, ", ", &"'#{&1}'")
  end
end
