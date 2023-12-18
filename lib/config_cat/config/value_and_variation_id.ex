defmodule ConfigCat.Config.ValueAndVariationId do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.Value

  @type opt ::
          {:value, Config.value()}
          | {:variation_id, Config.variation_id()}
  @type t :: %{String.t() => term()}

  @value "v"
  @variation_id "i"

  @spec value(t(), SettingType.t()) :: Config.value()
  @spec value(t(), SettingType.t(), Config.value() | nil) :: Config.value()
  def value(v, setting_type, default \\ nil) do
    case raw_value(v) do
      nil -> default
      value -> Value.get(value, setting_type, default)
    end
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  @spec variation_id(t(), Config.variation_id() | nil) :: Config.variation_id() | nil
  def variation_id(v, default \\ nil) do
    Map.get(v, @variation_id, default)
  end

  @spec variation_value(t(), Config.variation_id()) :: Value.t() | nil
  def variation_value(v, variation_id) do
    if variation_id(v) == variation_id do
      raw_value(v)
    end
  end

  defp raw_value(v) do
    Map.get(v, @value)
  end
end
