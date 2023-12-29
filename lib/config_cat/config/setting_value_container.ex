defmodule ConfigCat.Config.SettingValueContainer do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.SettingValue
  alias ConfigCat.Config.ValueError

  @type t :: %{String.t() => term()}

  @value "v"
  @variation_id "i"

  @spec value(t(), SettingType.t()) :: Config.value() | nil
  def value(v, setting_type) do
    case raw_value(v) do
      nil ->
        raise ValueError, "Value is missing"

      value ->
        SettingValue.get(value, setting_type)
    end
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  @spec variation_id(t(), Config.variation_id() | nil) :: Config.variation_id() | nil
  def variation_id(v, default \\ nil) do
    Map.get(v, @variation_id, default)
  end

  @spec variation_value(t(), Config.variation_id()) :: SettingValue.t() | nil
  def variation_value(v, variation_id) do
    if variation_id(v) == variation_id do
      raw_value(v)
    end
  end

  defp raw_value(v) do
    Map.get(v, @value)
  end
end
