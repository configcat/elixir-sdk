defmodule ConfigCat.Config.Value do
  @moduledoc false
  alias ConfigCat.Config

  require ConfigCat.Config.SettingType, as: SettingType

  @type t :: %{String.t() => Config.value()}

  @bool "b"
  @double "d"
  @int "i"
  @string "s"
  @unsupported_value "unsupported_value"

  @spec new(Config.value(), SettingType.t()) :: t()
  def new(value, setting_type) do
    %{type_key(setting_type) => value}
  end

  @spec get(t(), SettingType.t(), Config.value() | nil) :: Config.value() | nil
  def get(value, setting_type, default) do
    Map.get(value, type_key(setting_type), default)
  end

  @spec inferred_setting_type(t()) :: SettingType.t() | nil
  def inferred_setting_type(value) do
    Enum.find(
      [SettingType.bool(), SettingType.double(), SettingType.int(), SettingType.string()],
      &(get(value, &1, nil) != nil)
    )
  end

  defp type_key(setting_type) do
    case setting_type do
      SettingType.bool() -> @bool
      SettingType.double() -> @double
      SettingType.int() -> @int
      SettingType.string() -> @string
      _ -> @unsupported_value
    end
  end
end
