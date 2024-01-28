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

  @spec variation_value(t(), SettingType.t(), Config.variation_id()) :: Config.value() | nil
  def variation_value(v, setting_type, variation_id) do
    if variation_id(v) == variation_id do
      v |> value(setting_type) |> ensure_allowed_type()
    end
  end

  defp ensure_allowed_type(value) do
    unless SettingType.from_value(value) do
      raise ValueError, "Setting value '#{value}' is of an unsupported type."
    end
  end

  defp raw_value(v) do
    Map.get(v, @value)
  end
end
