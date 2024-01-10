defmodule ConfigCat.User do
  @moduledoc """
  Represents a user in your system; used for ConfigCat's Targeting feature.

  The User Object is an optional parameter when getting a feature flag or
  setting value from ConfigCat. It allows you to pass potential [Targeting
  rule](https://configcat.com/docs/advanced/targeting) variables to the
  ConfigCat SDK.

  Has the following properties:
  - `identifier`: **REQUIRED** We recommend using a UserID, Email address,
    or SessionID. Enables ConfigCat to differentiate your users from each
    other and to evaluate the setting values for percentage-based targeting.

  - `country`: **OPTIONAL** Fill this for location or country-based
    targeting. e.g: Turn on a feature for users in Canada only.

  - `email`: **OPTIONAL** By adding this parameter you will be able to
    create Email address-based targeting. e.g: Only turn on a feature
    for users with @example.com addresses.

  - `custom`: **OPTIONAL** This parameter will let you create targeting
    based on any user data you like. e.g: Age, Subscription type,
    User role, Device type, App version number, etc. `custom` is a map
    containing string or atom keys and string values.  When evaluating
    targeting rules, keys are case-sensitive, so make sure you specify
    your keys with the same capitalization as you use when defining
    your targeting rules.

  While `ConfigCat.User` is a struct, we also provide the `new/2` function
  to make it easier to create a new user object. Pass it the `identifier`
  and then either a keyword list or map containing the other properties
  you want to specify.

  e.g. `ConfigCat.User.new("IDENTIFIER", email: "user@example.com")`
  """
  use TypedStruct

  typedstruct do
    @typedoc "The ConfigCat user object."

    field :country, String.t()
    field :custom, custom(), default: %{}
    field :email, String.t()
    field :identifier, String.t(), enforce: true
  end

  @typedoc """
  Custom properties for additional targeting options.

  Can use either atoms or strings as keys; values must be strings.
  Keys are case-sensitive and must match the targeting rule exactly.
  """
  @type custom :: %{optional(String.t() | atom()) => String.t()}

  @typedoc """
  Additional values for creating a `User` struct.

  Can be either a keyword list or a maps, but any keys that don't
  match the field names of `t:t()` will be ignored.
  """
  @type options :: keyword() | map()

  @doc """
  Creates a new ConfigCat.User struct.

  This is provided as a convenience to make it easier to create a
  new user object.

  Pass it the `identifier` and then either a keyword list or map
  containing the other properties you want to specify.

  e.g. `ConfigCat.User.new("IDENTIFIER", email: "user@example.com")`
  """
  @spec new(String.t(), options()) :: t()
  def new(identifier, other_props \\ []) do
    struct!(%__MODULE__{identifier: identifier}, other_props)
  end

  @doc false
  @spec get_attribute(t(), String.t()) :: String.t() | nil
  def get_attribute(user, attribute) do
    do_get_attribute(user, attribute)
  end

  defp do_get_attribute(user, "Identifier"), do: user.identifier
  defp do_get_attribute(user, "Country"), do: user.country
  defp do_get_attribute(user, "Email"), do: user.email
  defp do_get_attribute(user, attribute), do: custom_attribute(user.custom, attribute)

  defp custom_attribute(custom, attribute) do
    case Enum.find(custom, fn {key, _value} ->
           to_string(key) == attribute
         end) do
      {_key, value} -> value
      _ -> nil
    end
  end
end
