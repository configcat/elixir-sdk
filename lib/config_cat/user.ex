defmodule ConfigCat.User do
  @enforce_keys :identifier
  defstruct [:identifier, country: "", email: "", custom: ""]

  def new(identifier, other_props \\ []) do
    %__MODULE__{identifier: identifier}
    |> struct!(other_props)
  end

  def get_attribute(user, attribute) do
    do_get_attribute(user, normalize(attribute))
  end

  defp do_get_attribute(user, "identifier"), do: user.identifier
  defp do_get_attribute(user, "country"), do: user.country
  defp do_get_attribute(user, "email"), do: user.email
  defp do_get_attribute(user, attribute), do: custom_attribute(user.custom, attribute)

  defp custom_attribute(nil, _attribute), do: ""
  defp custom_attribute("", _attribute), do: ""

  defp custom_attribute(custom, attribute) do
    case Enum.find(custom, fn {key, _value} ->
           normalize(key) == attribute
         end) do
      {_key, value} -> value
      _ -> ""
    end
  end

  defp normalize(attribute) do
    attribute
    |> to_string()
    |> String.downcase()
  end
end
