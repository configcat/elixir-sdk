defmodule ConfigCat.User do
  @enforce_keys :identifier
  defstruct [:identifier, country: nil, email: nil, custom: nil]

  def new(identifier, other_props \\ []) do
    %__MODULE__{identifier: identifier}
    |> struct!(other_props)
  end

  def get_attribute(user, attribute) do
    do_get_attribute(user, attribute)
  end

  defp do_get_attribute(user, "Identifier"), do: user.identifier
  defp do_get_attribute(user, "Country"), do: user.country
  defp do_get_attribute(user, "Email"), do: user.email
  defp do_get_attribute(user, attribute), do: custom_attribute(user.custom, attribute)

  defp custom_attribute(nil, _attribute), do: nil

  defp custom_attribute(custom, attribute) do
    case Enum.find(custom, fn {key, _value} ->
           key == attribute
         end) do
      {_key, value} -> value
      _ -> nil
    end
  end
end
