defmodule ConfigCat.Config.SettingValue do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.ValueError

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

  @spec get(t(), SettingType.t()) :: Config.value() | nil
  def get(value, setting_type) do
    case type_key(setting_type) do
      @unsupported_value ->
        raise ValueError, "Unsupported setting type"

      type_key ->
        case Map.get(value, type_key) do
          nil ->
            expected_type = SettingType.to_elixir_type(setting_type)
            raise ValueError, "Setting value is not of the expected type #{expected_type}"

          value ->
            :ok = ensure_value_matches_type_key(type_key, value)
            value
        end
    end
  end

  defp ensure_value_matches_type_key(@bool, value) when is_boolean(value), do: :ok
  defp ensure_value_matches_type_key(@string, value) when is_binary(value), do: :ok
  defp ensure_value_matches_type_key(@int, value) when is_integer(value), do: :ok
  # It's OK to have integer values for @double settings
  defp ensure_value_matches_type_key(@double, value) when is_number(value), do: :ok

  defp ensure_value_matches_type_key(type_key, value) do
    raise ValueError, "Setting value '#{value}' is not of the specified type #{type_key}"
  end

  @spec inferred_setting_type(t()) :: SettingType.t() | nil
  def inferred_setting_type(value) do
    Enum.find(
      [SettingType.bool(), SettingType.double(), SettingType.int(), SettingType.string()],
      fn setting_type ->
        !is_nil(Map.get(value, type_key(setting_type)))
      end
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
