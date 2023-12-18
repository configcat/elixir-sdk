defmodule ConfigCat.Config.PercentageOption do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.Value

  @type t :: %{String.t() => term()}

  @percentage "p"
  @value "v"
  @variation_id "i"

  @spec percentage(t()) :: non_neg_integer()
  def percentage(option) do
    Map.get(option, @percentage, 0)
  end

  @spec value(t(), SettingType.t()) :: Config.value() | nil
  def value(option, setting_type) do
    case raw_value(option) do
      nil -> nil
      value -> Value.get(value, setting_type, nil)
    end
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  def variation_id(option) do
    Map.get(option, @variation_id)
  end

  @spec variation_value(t(), Config.variation_id()) :: Value.t() | nil
  def variation_value(option, variation_id) do
    if variation_id(option) == variation_id do
      raw_value(option)
    end
  end

  defp raw_value(option) do
    Map.get(option, @value)
  end
end
