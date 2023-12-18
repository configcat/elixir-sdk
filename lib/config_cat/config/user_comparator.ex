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
  alias ConfigCat.Config.ComparatorMetadata, as: Metadata

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

  @metadata %{
    @is_one_of => %Metadata{description: "IS ONE OF", value_type: :string_list},
    @is_not_one_of => %Metadata{description: "IS NOT ONE OF", value_type: :string_list},
    @contains => %Metadata{description: "CONTAINS", value_type: :string},
    @does_not_contain => %Metadata{description: "DOES NOT CONTAIN", value_type: :string},
    @is_one_of_semver => %Metadata{description: "IS ONE OF (SemVer)", value_type: :string_list},
    @is_not_one_of_semver => %Metadata{description: "IS NOT ONE OF (SemVer)", value_type: :string_list},
    @less_than_semver => %Metadata{description: "< (SemVer)", value_type: :string},
    @less_than_equal_semver => %Metadata{description: "<= (SemVer)", value_type: :string},
    @greater_than_semver => %Metadata{description: "> (SemVer)", value_type: :string},
    @greater_than_equal_semver => %Metadata{description: ">= (SemVer)", value_type: :string},
    @equals_number => %Metadata{description: "= (Number)", value_type: :double},
    @not_equals_number => %Metadata{description: "<> (Number)", value_type: :double},
    @less_than_number => %Metadata{description: "< (Number)", value_type: :double},
    @less_than_equal_number => %Metadata{description: "<= (Number)", value_type: :double},
    @greater_than_number => %Metadata{description: "> (Number)", value_type: :double},
    @greater_than_equal_number => %Metadata{description: ">= (Number)", value_type: :double},
    @is_one_of_sensitive => %Metadata{description: "IS ONE OF (Sensitive)", value_type: :string_list},
    @is_not_one_of_sensitive => %Metadata{description: "IS NOT ONE OF (Sensitive)", value_type: :string_list}
  }

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
end
