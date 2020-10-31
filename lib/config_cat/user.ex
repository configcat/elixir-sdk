defmodule ConfigCat.User do
  @enforce_keys :identifier
  defstruct [:identifier, country: nil, email: nil, custom: %{}]

  @type custom :: %{optional(String.t() | atom()) => String.t()}
  @type options :: keyword() | map()
  @type t :: %__MODULE__{
          identifier: String.t(),
          country: String.t() | nil,
          email: String.t() | nil,
          custom: custom()
        }

  @spec new(String.t(), options()) :: t()
  def new(identifier, other_props \\ []) do
    %__MODULE__{identifier: identifier}
    |> struct!(other_props)
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
