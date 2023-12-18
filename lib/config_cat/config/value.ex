defmodule ConfigCat.Config.Value do
  @moduledoc false
  alias ConfigCat.Config

  require ConfigCat.Config.SettingType, as: SettingType

  @type t :: %{String.t() => Config.value()}

  @bool "b"
  @double "d"
  @int "i"
  @string "s"

  @spec new(Config.value(), SettingType.t()) :: t()
  def new(value, setting_type) do
    %{type_key(setting_type) => value}
  end

  @spec get(t(), SettingType.t(), Config.value() | nil) :: Config.value() | nil
  def get(value, setting_type, default) do
    Map.get(value, type_key(setting_type), default)
  end

  defp type_key(setting_type) do
    case setting_type do
      SettingType.bool() -> @bool
      SettingType.double() -> @double
      SettingType.int() -> @int
      SettingType.string() -> @string
    end
  end
end
