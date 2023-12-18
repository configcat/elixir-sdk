defmodule ConfigCat.Config.SettingType do
  @moduledoc false
  alias ConfigCat.Config

  @type t :: non_neg_integer()

  defmacro bool, do: 0
  defmacro string, do: 1
  defmacro int, do: 2
  defmacro double, do: 3

  @spec from_value(Config.value()) :: t()
  def from_value(value) when is_boolean(value), do: bool()
  def from_value(value) when is_binary(value), do: string()
  def from_value(value) when is_integer(value), do: int()
  def from_value(value) when is_number(value), do: double()
end
