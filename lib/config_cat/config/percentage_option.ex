defmodule ConfigCat.Config.PercentageOption do
  @moduledoc false
  alias ConfigCat.Config.SettingValueContainer

  @type t :: %{String.t() => term()}

  @percentage "p"

  @spec percentage(t()) :: non_neg_integer()
  def percentage(option) do
    Map.get(option, @percentage, 0)
  end

  defdelegate value(option, setting_type), to: SettingValueContainer
  defdelegate variation_id(option, default \\ nil), to: SettingValueContainer
  defdelegate variation_value(option, variation_id), to: SettingValueContainer
end
