defmodule ConfigCat.Config.Setting do
  @moduledoc false
  alias ConfigCat.Config
  alias ConfigCat.Config.PercentageOption
  alias ConfigCat.Config.Preferences
  alias ConfigCat.Config.SettingType
  alias ConfigCat.Config.SettingValue
  alias ConfigCat.Config.SettingValueContainer
  alias ConfigCat.Config.TargetingRule

  @type opt :: {:setting_type, SettingType.t()} | {:value, Config.value()}
  @type t :: %{String.t() => term()}

  @inline_salt "inline_salt"
  @percentage_option_attribute "a"
  @percentage_options "p"
  @setting_type "t"
  @targeting_rules "r"
  @value "v"

  @spec new([opt]) :: t()
  def new(opts \\ []) do
    case opts[:value] do
      nil ->
        %{@value => nil}

      value ->
        setting_type = SettingType.from_value(value)

        %{
          @setting_type => setting_type,
          @value => SettingValue.new(value, setting_type)
        }
    end
  end

  @spec percentage_option_attribute(t()) :: String.t() | nil
  def percentage_option_attribute(setting) do
    Map.get(setting, @percentage_option_attribute)
  end

  @spec percentage_options(t()) :: [PercentageOption.t()]
  def percentage_options(setting) do
    Map.get(setting, @percentage_options, [])
  end

  @spec salt(t()) :: Preferences.salt()
  def salt(setting) do
    Map.get(setting, @inline_salt, "")
  end

  @spec setting_type(t()) :: SettingType.t() | nil
  def setting_type(setting) do
    Map.get(setting, @setting_type)
  end

  @spec targeting_rules(t()) :: [TargetingRule.t()]
  def targeting_rules(setting) do
    Map.get(setting, @targeting_rules, [])
  end

  @spec value(t()) :: Config.value()
  @spec value(t(), Config.value() | nil) :: Config.value()
  def value(setting, default \\ nil) do
    SettingValueContainer.value(setting, setting_type(setting), default)
  end

  defdelegate variation_id(setting, default \\ nil), to: SettingValueContainer

  @spec variation_value(t(), Config.variation_id()) :: Config.value() | nil
  def variation_value(setting, variation_id) do
    if variation_id(setting) == variation_id do
      value(setting)
    else
      case targeting_rule_variation_value(setting, variation_id) do
        nil ->
          percentage_rule_variation_value(setting, variation_id)

        targeting_value ->
          targeting_value
      end
    end
  end

  defp targeting_rule_variation_value(setting, variation_id) do
    setting
    |> targeting_rules()
    |> Enum.find_value(nil, &TargetingRule.variation_value(&1, variation_id))
  end

  defp percentage_rule_variation_value(setting, variation_id) do
    setting
    |> percentage_options()
    |> Enum.find_value(nil, &PercentageOption.variation_value(&1, variation_id))
  end
end