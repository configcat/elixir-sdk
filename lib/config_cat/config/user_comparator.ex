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
  alias ConfigCat.Config.UserCondition

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
  @equals_hashed 20
  @not_equals_hashed 21
  @starts_with_any_of_hashed 22
  @not_starts_with_any_of_hashed 23
  @ends_with_any_of_hashed 24
  @not_ends_with_any_of_hashed 25
  @array_contains_any_of_hashed 26
  @array_not_contains_any_of_hashed 27
  @equals 28
  @not_equals 29
  @starts_with_any_of 30
  @not_starts_with_any_of 31
  @ends_with_any_of 32
  @not_ends_with_any_of 33
  @array_contains_any_of 34
  @array_not_contains_any_of 35

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
    @not_equals_number => %Metadata{description: "!=", value_type: :double},
    @less_than_number => %Metadata{description: "<", value_type: :double},
    @less_than_equal_number => %Metadata{description: "<=", value_type: :double},
    @greater_than_number => %Metadata{description: ">", value_type: :double},
    @greater_than_equal_number => %Metadata{description: ">=", value_type: :double},
    @is_one_of_hashed => %Metadata{description: "IS ONE OF", value_type: :string_list},
    @is_not_one_of_hashed => %Metadata{description: "IS NOT ONE OF", value_type: :string_list},
    @before_datetime => %Metadata{description: "BEFORE", value_type: :double},
    @after_datetime => %Metadata{description: "AFTER", value_type: :double},
    @equals_hashed => %Metadata{description: "EQUALS", value_type: :string},
    @not_equals_hashed => %Metadata{description: "NOT EQUALS", value_type: :string},
    @starts_with_any_of_hashed => %Metadata{description: "STARTS WITH ANY OF", value_type: :string_list},
    @not_starts_with_any_of_hashed => %Metadata{description: "NOT STARTS WITH ANY OF", value_type: :string_list},
    @ends_with_any_of_hashed => %Metadata{description: "ENDS WITH ANY OF", value_type: :string_list},
    @not_ends_with_any_of_hashed => %Metadata{description: "NOT ENDS WITH ANY OF", value_type: :string_list},
    @array_contains_any_of_hashed => %Metadata{description: "ARRAY CONTAINS ANY OF", value_type: :string_list},
    @array_not_contains_any_of_hashed => %Metadata{description: "NOT ARRAY CONTAINS ANY OF", value_type: :string_list},
    @equals => %Metadata{description: "EQUALS", value_type: :string},
    @not_equals => %Metadata{description: "NOT EQUALS", value_type: :string},
    @starts_with_any_of => %Metadata{description: "STARTS WITH ANY OF", value_type: :string_list},
    @not_starts_with_any_of => %Metadata{description: "NOT STARTS WITH ANY OF", value_type: :string_list},
    @ends_with_any_of => %Metadata{description: "ENDS WITH ANY OF", value_type: :string_list},
    @not_ends_with_any_of => %Metadata{description: "NOT ENDS WITH ANY OF", value_type: :string_list},
    @array_contains_any_of => %Metadata{description: "ARRAY CONTAINS ANY OF", value_type: :string_list},
    @array_not_contains_any_of => %Metadata{description: "NOT ARRAY CONTAINS ANY OF", value_type: :string_list}
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
          UserCondition.comparison_value(),
          context_salt :: Config.salt(),
          salt :: Config.salt()
        ) :: result()

  def compare(@is_one_of, user_value, comparison_values, _context_salt, _salt) do
    with {:ok, text} <- as_text(user_value) do
      {:ok, text in comparison_values}
    end
  end

  def compare(@is_not_one_of, user_value, comparison_values, context_salt, salt) do
    @is_one_of |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@contains_any_of, user_value, comparison_values, _context_salt, _salt) do
    with {:ok, text} <- as_text(user_value) do
      result = Enum.any?(comparison_values, &String.contains?(text, &1))
      {:ok, result}
    end
  end

  def compare(@not_contains_any_of, user_value, comparison_values, context_salt, salt) do
    @contains_any_of |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@is_one_of_semver, user_value, comparison_values, _context_salt, _salt) do
    with {:ok, user_version} <- to_version(user_value),
         {:ok, comparison_versions} <- to_versions(comparison_values) do
      result = Enum.any?(comparison_versions, &(Version.compare(user_version, &1) == :eq))
      {:ok, result}
    end
  end

  def compare(@is_not_one_of_semver, user_value, comparison_values, context_salt, salt) do
    @is_one_of_semver |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@less_than_semver, user_value, comparison_value, _context_salt, _salt) do
    compare_semver(user_value, comparison_value, [:lt])
  end

  def compare(@less_than_equal_semver, user_value, comparison_value, _context_salt, _salt) do
    compare_semver(user_value, comparison_value, [:lt, :eq])
  end

  def compare(@greater_than_semver, user_value, comparison_value, _context_salt, _salt) do
    compare_semver(user_value, comparison_value, [:gt])
  end

  def compare(@greater_than_equal_semver, user_value, comparison_value, _context_salt, _salt) do
    compare_semver(user_value, comparison_value, [:gt, :eq])
  end

  def compare(@equals_number, user_value, comparison_value, _context_salt, _salt) do
    compare_numbers(user_value, comparison_value, &==/2)
  end

  def compare(@not_equals_number, user_value, comparison_value, _context_salt, _salt) do
    compare_numbers(user_value, comparison_value, &!==/2)
  end

  def compare(@less_than_number, user_value, comparison_value, _context_salt, _salt) do
    compare_numbers(user_value, comparison_value, &</2)
  end

  def compare(@less_than_equal_number, user_value, comparison_value, _context_salt, _salt) do
    compare_numbers(user_value, comparison_value, &<=/2)
  end

  def compare(@greater_than_number, user_value, comparison_value, _context_salt, _salt) do
    compare_numbers(user_value, comparison_value, &>/2)
  end

  def compare(@greater_than_equal_number, user_value, comparison_value, _context_salt, _salt) do
    compare_numbers(user_value, comparison_value, &>=/2)
  end

  def compare(@is_one_of_hashed, user_value, comparison_values, context_salt, salt) do
    with {:ok, text} <- as_text(user_value) do
      result = hash_value(text, context_salt, salt) in comparison_values
      {:ok, result}
    end
  end

  def compare(@is_not_one_of_hashed, user_value, comparison_values, context_salt, salt) do
    @is_one_of_hashed |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@before_datetime, user_value, comparison_value, _context_salt, _salt) do
    compare_datetimes(user_value, comparison_value, [:lt])
  end

  def compare(@after_datetime, user_value, comparison_value, _context_salt, _salt) do
    compare_datetimes(user_value, comparison_value, [:gt])
  end

  def compare(@equals_hashed, user_value, comparison_value, context_salt, salt) do
    with {:ok, text} <- as_text(user_value) do
      result = hash_value(text, context_salt, salt) == comparison_value
      {:ok, result}
    end
  end

  def compare(@not_equals_hashed, user_value, comparison_value, context_salt, salt) do
    @equals_hashed |> compare(user_value, comparison_value, context_salt, salt) |> negate()
  end

  def compare(@starts_with_any_of_hashed, user_value, comparison_values, context_salt, salt) do
    with {:ok, text} <- as_text(user_value) do
      result =
        Enum.any?(
          comparison_values,
          fn comparison ->
            {length, comparison_string} = parse_comparison(comparison)

            if byte_size(text) >= length do
              hashed = text |> binary_part(0, length) |> hash_value(context_salt, salt)
              hashed == comparison_string
            else
              false
            end
          end
        )

      {:ok, result}
    end
  end

  def compare(@not_starts_with_any_of_hashed, user_value, comparison_values, context_salt, salt) do
    @starts_with_any_of_hashed |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@ends_with_any_of_hashed, user_value, comparison_values, context_salt, salt) do
    with {:ok, text} <- as_text(user_value) do
      result =
        Enum.any?(
          comparison_values,
          fn comparison ->
            {length, comparison_string} = parse_comparison(comparison)

            if byte_size(text) >= length do
              hashed = text |> binary_part(byte_size(text), -length) |> hash_value(context_salt, salt)
              hashed == comparison_string
            else
              false
            end
          end
        )

      {:ok, result}
    end
  end

  def compare(@not_ends_with_any_of_hashed, user_value, comparison_values, context_salt, salt) do
    @ends_with_any_of_hashed |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@array_contains_any_of_hashed, user_value, comparison_values, context_salt, salt) do
    with {:ok, user_values} <- to_string_list(user_value) do
      hashed_user_values = Enum.map(user_values, &hash_value(&1, context_salt, salt))
      result = Enum.any?(comparison_values, &(&1 in hashed_user_values))

      {:ok, result}
    end
  end

  def compare(@array_not_contains_any_of_hashed, user_value, comparison_values, context_salt, salt) do
    @array_contains_any_of_hashed |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@equals, user_value, comparison_value, _context_salt, _salt) do
    with {:ok, text} <- as_text(user_value) do
      result = text == comparison_value
      {:ok, result}
    end
  end

  def compare(@not_equals, user_value, comparison_value, context_salt, salt) do
    @equals |> compare(user_value, comparison_value, context_salt, salt) |> negate()
  end

  def compare(@starts_with_any_of, user_value, comparison_values, _context_salt, _salt) do
    with {:ok, text} <- as_text(user_value) do
      result = Enum.any?(comparison_values, &String.starts_with?(text, &1))
      {:ok, result}
    end
  end

  def compare(@not_starts_with_any_of, user_value, comparison_values, context_salt, salt) do
    @starts_with_any_of |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@ends_with_any_of, user_value, comparison_values, _context_salt, _salt) do
    with {:ok, text} <- as_text(user_value) do
      result = Enum.any?(comparison_values, &String.ends_with?(text, &1))
      {:ok, result}
    end
  end

  def compare(@not_ends_with_any_of, user_value, comparison_values, context_salt, salt) do
    @ends_with_any_of |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(@array_contains_any_of, user_value, comparison_values, _context_salt, _salt) do
    with {:ok, user_values} <- to_string_list(user_value) do
      result = Enum.any?(comparison_values, &(&1 in user_values))
      {:ok, result}
    end
  end

  def compare(@array_not_contains_any_of, user_value, comparison_values, context_salt, salt) do
    @array_contains_any_of |> compare(user_value, comparison_values, context_salt, salt) |> negate()
  end

  def compare(_comparator, _user_value, _comparison_value, _context_salt, _salt) do
    {:ok, false}
  end

  defp compare_semver(user_value, comparison_value, valid_comparisons) do
    with {:ok, user_version} <- to_version(user_value),
         {:ok, comparison_version} <- to_version(comparison_value) do
      result = Version.compare(user_version, comparison_version)
      {:ok, result in valid_comparisons}
    end
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

  defp hash_value(value, context_salt, salt) do
    salted = value <> salt <> context_salt

    :sha256
    |> :crypto.hash(salted)
    |> Base.encode16()
    |> String.downcase()
  end

  defp parse_comparison(value) do
    [length_string, comparison_string] = String.split(value, "_", parts: 2)

    {String.to_integer(length_string), comparison_string}
  end

  defp as_text(value) when is_binary(value), do: {:ok, value}

  defp as_text(value) do
    user_value_to_string(value)
  end

  defp user_value_to_string(nil), do: {:ok, nil}

  defp user_value_to_string(%DateTime{} = dt) do
    with {:ok, seconds} <- to_unix_seconds(dt) do
      {:ok, to_string(seconds)}
    end
  end

  defp user_value_to_string(%NaiveDateTime{} = naive) do
    naive |> DateTime.from_naive!("Etc/UTC") |> user_value_to_string()
  end

  defp user_value_to_string(value) when is_list(value) do
    with {:ok, list} <- to_string_list(value) do
      {:ok, to_string(list)}
    end
  end

  defp user_value_to_string(value), do: {:ok, to_string(value)}

  defp to_float(value) when is_float(value), do: {:ok, value}
  defp to_float(value) when is_integer(value), do: {:ok, value * 1.0}

  defp to_float(value) when is_binary(value) do
    value
    |> String.replace(",", ".")
    |> Float.parse()
    |> case do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid_float}
    end
  end

  defp to_float(_value), do: {:error, :invalid_float}

  defp to_string_list(value) when is_list(value), do: {:ok, value}

  defp to_string_list(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_list(decoded) -> {:ok, decoded}
      _ -> {:error, :invalid_string_list}
    end
  end

  defp to_string_list(_value), do: {:error, :invalid_string_list}

  @spec to_unix_seconds(DateTime.t() | NaiveDateTime.t() | number() | String.t()) ::
          {:ok, float()} | {:error, :invalid_float}
  def to_unix_seconds(%DateTime{} = value) do
    {:ok, DateTime.to_unix(value, :millisecond) / 1000.0}
  end

  def to_unix_seconds(%NaiveDateTime{} = value) do
    value |> DateTime.from_naive!("Etc/UTC") |> to_unix_seconds()
  end

  def to_unix_seconds(value) do
    to_float(value)
  end

  defp to_versions(values) do
    values
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, versions} ->
      case to_version(value) do
        {:ok, version} -> {:cont, {:ok, [version | versions]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, versions} -> {:ok, Enum.reverse(versions)}
      error -> error
    end
  end

  defp to_version(value) do
    value
    |> to_string()
    |> String.trim()
    |> Version.parse()
    |> case do
      {:ok, version} -> {:ok, version}
      :error -> {:error, :invalid_version}
    end
  end

  defp negate({:ok, result}), do: {:ok, !result}
  defp negate(error), do: error
end
