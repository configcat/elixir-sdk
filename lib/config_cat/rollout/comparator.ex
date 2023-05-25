defmodule ConfigCat.Rollout.Comparator do
  @moduledoc false

  alias ConfigCat.Config
  alias Version.InvalidVersionError

  @type comparator :: Config.comparator()
  @type description :: String.t()
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

  @descriptions %{
    @is_one_of => "IS ONE OF",
    @is_not_one_of => "IS NOT ONE OF",
    @contains => "CONTAINS",
    @does_not_contain => "DOES NOT CONTAIN",
    @is_one_of_semver => "IS ONE OF (SemVer)",
    @is_not_one_of_semver => "IS NOT ONE OF (SemVer)",
    @less_than_semver => "< (SemVer)",
    @less_than_equal_semver => "<= (SemVer)",
    @greater_than_semver => "> (SemVer)",
    @greater_than_equal_semver => ">= (SemVer)",
    @equals_number => "= (Number)",
    @not_equals_number => "<> (Number)",
    @less_than_number => "< (Number)",
    @less_than_equal_number => "<= (Number)",
    @greater_than_number => "> (Number)",
    @greater_than_equal_number => ">= (Number)",
    @is_one_of_sensitive => "IS ONE OF (Sensitive)",
    @is_not_one_of_sensitive => "IS NOT ONE OF (Sensitive)"
  }

  @spec description(comparator()) :: description()
  def description(comparator) do
    Map.get(@descriptions, comparator, "Unsupported comparator")
  end

  @spec compare(comparator(), String.t(), String.t()) :: result()

  def compare(@is_one_of, user_value, comparison_value),
    do: is_one_of(user_value, comparison_value)

  def compare(@is_not_one_of, user_value, comparison_value),
    do: is_one_of(user_value, comparison_value) |> negate()

  def compare(@contains, user_value, comparison_value),
    do: contains(user_value, comparison_value)

  def compare(@does_not_contain, user_value, comparison_value),
    do: contains(user_value, comparison_value) |> negate()

  def compare(@is_one_of_semver, user_value, comparison_value),
    do: is_one_of_semver(user_value, comparison_value)

  def compare(@is_not_one_of_semver, user_value, comparison_value),
    do: is_one_of_semver(user_value, comparison_value) |> negate()

  def compare(@less_than_semver, user_value, comparison_value),
    do: compare_semver(user_value, comparison_value, [:lt])

  def compare(@less_than_equal_semver, user_value, comparison_value),
    do: compare_semver(user_value, comparison_value, [:lt, :eq])

  def compare(@greater_than_semver, user_value, comparison_value),
    do: compare_semver(user_value, comparison_value, [:gt])

  def compare(@greater_than_equal_semver, user_value, comparison_value),
    do: compare_semver(user_value, comparison_value, [:gt, :eq])

  def compare(@equals_number, user_value, comparison_value),
    do: compare_numbers(user_value, comparison_value, &==/2)

  def compare(@not_equals_number, user_value, comparison_value),
    do: compare_numbers(user_value, comparison_value, &!==/2)

  def compare(@less_than_number, user_value, comparison_value),
    do: compare_numbers(user_value, comparison_value, &</2)

  def compare(@less_than_equal_number, user_value, comparison_value),
    do: compare_numbers(user_value, comparison_value, &<=/2)

  def compare(@greater_than_number, user_value, comparison_value),
    do: compare_numbers(user_value, comparison_value, &>/2)

  def compare(@greater_than_equal_number, user_value, comparison_value),
    do: compare_numbers(user_value, comparison_value, &>=/2)

  def compare(@is_one_of_sensitive, user_value, comparison_value),
    do: is_one_of_sensitive(user_value, comparison_value)

  def compare(@is_not_one_of_sensitive, user_value, comparison_value),
    do: is_one_of_sensitive(user_value, comparison_value) |> negate()

  def compare(_comparator, _user_value, _comparison_value) do
    {:ok, false}
  end

  defp is_one_of(user_value, comparison_value) do
    result =
      comparison_value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.member?(user_value)

    {:ok, result}
  end

  defp contains(user_value, comparison_value) do
    result = String.contains?(user_value, comparison_value)
    {:ok, result}
  end

  defp is_one_of_semver(user_value, comparison_value) do
    user_version = Version.parse!(user_value)

    result =
      comparison_value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Version.parse!/1)
      |> Enum.any?(fn version -> Version.compare(user_version, version) == :eq end)

    {:ok, result}
  rescue
    error in Version.InvalidVersionError ->
      {:error, error}
  end

  defp is_one_of_sensitive(user_value, comparison_value) do
    user_value
    |> hash_value()
    |> is_one_of(comparison_value)
  end

  defp hash_value(value) do
    :crypto.hash(:sha, value)
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
    value |> String.trim() |> Version.parse!()
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
