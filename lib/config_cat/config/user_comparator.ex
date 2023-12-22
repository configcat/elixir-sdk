defmodule ConfigCat.Config.ComparatorMetadata do
  @moduledoc false
  use TypedStruct

  @type value_type :: :double | :string | :string_list

  typedstruct enforce: true do
    field :description, String.t()
    field :value_type, value_type()
  end
end

defmodule ConfigCat.Config.UserComparator do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.ComparatorMetadata, as: Metadata
  alias ConfigCat.Config.ComparisonRule
  alias ConfigCat.Config.Preferences
  alias Version.InvalidVersionError

  @is_one_of 0
  @is_not_one_of 1
  @contains_any_of 2
  @not_contains_any_of 3
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
  @is_one_of_hashed 16
  @is_not_one_of_hashed 17
  @before_datetime 18
  @after_datetime 19

  @metadata %{
    @is_one_of => %Metadata{description: "IS ONE OF", value_type: :string_list},
    @is_not_one_of => %Metadata{description: "IS NOT ONE OF", value_type: :string_list},
    @contains_any_of => %Metadata{description: "CONTAINS ANY OF", value_type: :string_list},
    @not_contains_any_of => %Metadata{description: "NOT CONTAINS ANY OF", value_type: :string_list},
    @is_one_of_semver => %Metadata{description: "IS ONE OF", value_type: :string_list},
    @is_not_one_of_semver => %Metadata{description: "IS NOT ONE OF", value_type: :string_list},
    @less_than_semver => %Metadata{description: "<", value_type: :string},
    @less_than_equal_semver => %Metadata{description: "<=", value_type: :string},
    @greater_than_semver => %Metadata{description: ">", value_type: :string},
    @greater_than_equal_semver => %Metadata{description: ">=", value_type: :string},
    @equals_number => %Metadata{description: "=", value_type: :double},
    @not_equals_number => %Metadata{description: "<>", value_type: :double},
    @less_than_number => %Metadata{description: "<", value_type: :double},
    @less_than_equal_number => %Metadata{description: "<=", value_type: :double},
    @greater_than_number => %Metadata{description: ">", value_type: :double},
    @greater_than_equal_number => %Metadata{description: ">=", value_type: :double},
    @is_one_of_hashed => %Metadata{description: "IS ONE OF", value_type: :string_list},
    @is_not_one_of_hashed => %Metadata{description: "IS NOT ONE OF", value_type: :string_list},
    @before_datetime => %Metadata{description: "BEFORE", value_type: :double},
    @after_datetime => %Metadata{description: "AFTER", value_type: :double}
  }

  @type result :: {:ok, boolean()} | {:error, Exception.t()}
  @type t :: non_neg_integer()
  @type value_type :: Metadata.value_type()

  @spec description(t()) :: String.t()
  def description(comparator) do
    case Map.get(@metadata, comparator) do
      nil -> "Unsupported comparator"
      %Metadata{} = metadata -> metadata.description
    end
  end

  @spec value_type(t()) :: value_type()
  def value_type(comparator) do
    %Metadata{} = metadata = Map.fetch!(@metadata, comparator)
    metadata.value_type
  end

  @spec compare(
          t(),
          Config.value(),
          ComparisonRule.comparison_value(),
          context_salt :: Preferences.salt(),
          salt :: Preferences.salt()
        ) :: result()

  def compare(@is_one_of, user_value, comparison_value, _context_salt, _salt), do: is_one_of(user_value, comparison_value)

  def compare(@is_not_one_of, user_value, comparison_value, _context_salt, _salt),
    do: user_value |> is_one_of(comparison_value) |> negate()

  def compare(@contains_any_of, user_value, comparison_value, _context_salt, _salt),
    do: contains_any_of(user_value, comparison_value)

  def compare(@not_contains_any_of, user_value, comparison_value, _context_salt, _salt),
    do: user_value |> contains_any_of(comparison_value) |> negate()

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

  def compare(@is_one_of_hashed, user_value, comparison_value, context_salt, salt),
    do: is_one_of_hashed(user_value, comparison_value, context_salt, salt)

  def compare(@is_not_one_of_hashed, user_value, comparison_value, context_salt, salt),
    do: user_value |> is_one_of_hashed(comparison_value, context_salt, salt) |> negate()

  def compare(@before_datetime, user_value, comparison_value, _context_salt, _salt),
    do: compare_datetimes(user_value, comparison_value, [:lt])

  def compare(@after_datetime, user_value, comparison_value, _context_salt, _salt),
    do: compare_datetimes(user_value, comparison_value, [:gt])

  def compare(_comparator, _user_value, _comparison_value, _context_salt, _salt) do
    {:ok, false}
  end

  defp is_one_of(user_value, comparison_value) do
    result = to_string(user_value) in comparison_value

    {:ok, result}
  end

  defp contains_any_of(user_value, comparison_value) do
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
    error in InvalidVersionError ->
      {:error, error}
  end

  defp compare_semver(user_value, comparison_value, valid_comparisons) do
    user_version = to_version(user_value)
    comparison_version = to_version(comparison_value)
    result = Version.compare(user_version, comparison_version)
    {:ok, result in valid_comparisons}
  rescue
    error in InvalidVersionError -> {:error, error}
  end

  defp compare_numbers(user_value, comparison_value, operator) do
    with {:ok, user_float} <- to_float(user_value),
         {:ok, comparison_float} <- to_float(comparison_value) do
      {:ok, operator.(user_float, comparison_float)}
    end
  end

  defp compare_datetimes(user_value, comparison_value, valid_comparisons) do
    with {:ok, user_seconds} <- to_unix_seconds(user_value),
         {:ok, comparison_seconds} <- to_float(comparison_value) do
      result =
        cond do
          user_seconds < comparison_seconds -> :lt
          user_seconds > comparison_seconds -> :gt
          true -> :eq
        end

      {:ok, result in valid_comparisons}
    else
      {:error, :invalid_float} -> {:error, :invalid_datetime}
    end
  end

  defp is_one_of_hashed(user_value, comparison_value, context_salt, salt) do
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

  defp to_float(value) do
    value
    |> to_string()
    |> String.replace(",", ".")
    |> Float.parse()
    |> case do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid_float}
    end
  end

  defp to_unix_seconds(%DateTime{} = value) do
    {:ok, DateTime.to_unix(value)}
  end

  defp to_unix_seconds(value) do
    to_float(value)
  end

  defp to_version(value) do
    value |> to_string() |> String.trim() |> Version.parse!()
  end

  defp negate({:ok, result}), do: {:ok, !result}
  defp negate(error), do: error
end
