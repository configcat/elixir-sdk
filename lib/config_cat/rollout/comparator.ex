defmodule ConfigCat.Rollout.Comparator do
  @moduledoc false

  alias ConfigCat.Config
  alias ConfigCat.Config.ComparisonRule
  alias ConfigCat.Config.Preferences
  alias Version.InvalidVersionError

  @type comparator :: Config.comparator()
  @type result :: {:ok, boolean()} | {:error, Exception.t()}

  @is_one_of 0
  @is_not_one_of 1
  @contains 2
  @does_not_contain 3
  @is_one_of_semver 4
  @is_not_one_of_semver 5
  @less_than_semver 6
  @less_than_equal_semver 7
  @greater_than_semver 8
  @greater_than_equal_semver 9
  @equals_number 10
  @not_equals_number 11
  @less_than_number 12
  @less_than_equal_number 13
  @greater_than_number 14
  @greater_than_equal_number 15
  @is_one_of_sensitive 16
  @is_not_one_of_sensitive 17

  @spec compare(
          comparator(),
          Config.value(),
          ComparisonRule.comparison_value(),
          context_salt :: Preferences.salt(),
          salt :: Preferences.salt()
        ) :: result()

  def compare(@is_one_of, user_value, comparison_value, _context_salt, _salt), do: is_one_of(user_value, comparison_value)

  def compare(@is_not_one_of, user_value, comparison_value, _context_salt, _salt),
    do: user_value |> is_one_of(comparison_value) |> negate()

  def compare(@contains, user_value, comparison_value, _context_salt, _salt), do: contains(user_value, comparison_value)

  def compare(@does_not_contain, user_value, comparison_value, _context_salt, _salt),
    do: user_value |> contains(comparison_value) |> negate()

  def compare(@is_one_of_semver, user_value, comparison_value, _context_salt, _salt),
    do: is_one_of_semver(user_value, comparison_value)

  def compare(@is_not_one_of_semver, user_value, comparison_value, _context_salt, _salt),
    do: user_value |> is_one_of_semver(comparison_value) |> negate()

  def compare(@less_than_semver, user_value, comparison_value, _context_salt, _salt),
    do: compare_semver(user_value, comparison_value, [:lt])

  def compare(@less_than_equal_semver, user_value, comparison_value, _context_salt, _salt),
    do: compare_semver(user_value, comparison_value, [:lt, :eq])

  def compare(@greater_than_semver, user_value, comparison_value, _context_salt, _salt),
    do: compare_semver(user_value, comparison_value, [:gt])

  def compare(@greater_than_equal_semver, user_value, comparison_value, _context_salt, _salt),
    do: compare_semver(user_value, comparison_value, [:gt, :eq])

  def compare(@equals_number, user_value, comparison_value, _context_salt, _salt),
    do: compare_numbers(user_value, comparison_value, &==/2)

  def compare(@not_equals_number, user_value, comparison_value, _context_salt, _salt),
    do: compare_numbers(user_value, comparison_value, &!==/2)

  def compare(@less_than_number, user_value, comparison_value, _context_salt, _salt),
    do: compare_numbers(user_value, comparison_value, &</2)

  def compare(@less_than_equal_number, user_value, comparison_value, _context_salt, _salt),
    do: compare_numbers(user_value, comparison_value, &<=/2)

  def compare(@greater_than_number, user_value, comparison_value, _context_salt, _salt),
    do: compare_numbers(user_value, comparison_value, &>/2)

  def compare(@greater_than_equal_number, user_value, comparison_value, _context_salt, _salt),
    do: compare_numbers(user_value, comparison_value, &>=/2)

  def compare(@is_one_of_sensitive, user_value, comparison_value, context_salt, salt),
    do: is_one_of_sensitive(user_value, comparison_value, context_salt, salt)

  def compare(@is_not_one_of_sensitive, user_value, comparison_value, context_salt, salt),
    do: user_value |> is_one_of_sensitive(comparison_value, context_salt, salt) |> negate()

  def compare(_comparator, _user_value, _comparison_value, _context_salt, _salt) do
    {:ok, false}
  end

  defp is_one_of(user_value, comparison_value) do
    result = to_string(user_value) in comparison_value

    {:ok, result}
  end

  defp contains(user_value, comparison_value) do
    result = String.contains?(to_string(user_value), to_string(comparison_value))
    {:ok, result}
  end

  defp is_one_of_semver(user_value, comparison_value) do
    user_version = to_version(user_value)

    result =
      comparison_value
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Version.parse!/1)
      |> Enum.any?(fn version -> Version.compare(user_version, version) == :eq end)

    {:ok, result}
  rescue
    error in Version.InvalidVersionError ->
      {:error, error}
  end

  defp is_one_of_sensitive(user_value, comparison_value, context_salt, salt) do
    user_value
    |> hash_value(context_salt, salt)
    |> is_one_of(comparison_value)
  end

  defp hash_value(value, context_salt, salt) do
    salted = to_string(value <> salt <> context_salt)

    :sha256
    |> :crypto.hash(salted)
    |> Base.encode16()
    |> String.downcase()
  end

  defp compare_semver(user_value, comparison_value, valid_comparisons) do
    user_version = to_version(user_value)
    comparison_version = to_version(comparison_value)
    result = Version.compare(user_version, comparison_version) in valid_comparisons
    {:ok, result}
  rescue
    error in InvalidVersionError -> {:error, error}
  end

  defp to_version(value) do
    value |> to_string() |> String.trim() |> Version.parse!()
  end

  defp compare_numbers(user_value, comparison_value, operator) do
    with {user_float, _} <- to_float(user_value),
         {comparison_float, _} <- to_float(comparison_value) do
      {:ok, operator.(user_float, comparison_float)}
    else
      :error -> {:error, :invalid_float}
    end
  end

  defp to_float(value) do
    value |> to_string() |> String.replace(",", ".") |> Float.parse()
  end

  defp negate({:ok, result}), do: {:ok, !result}
  defp negate(error), do: error
end
