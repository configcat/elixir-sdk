defmodule ConfigCat.Config.SettingType do
  @moduledoc false
  alias ConfigCat.Config

  @type t :: non_neg_integer()

  defmacro bool, do: 0
  defmacro string, do: 1
  defmacro int, do: 2
  defmacro double, do: 3

  @spec from_value(Config.value()) :: t() | nil
  def from_value(value) when is_boolean(value), do: bool()
  def from_value(value) when is_binary(value), do: string()
  def from_value(value) when is_integer(value), do: int()
  def from_value(value) when is_number(value), do: double()
  def from_value(_value), do: nil

  @spec infer_elixir_type(Config.value()) :: String.t() | nil
  def infer_elixir_type(value) do
    value |> from_value() |> to_elixir_type()
  end

  @spec to_elixir_type(t()) :: String.t() | nil
  def to_elixir_type(bool()), do: "boolean()"
  def to_elixir_type(string()), do: "String.t()"
  def to_elixir_type(int()), do: "integer()"
  def to_elixir_type(double()), do: "float()"
  def to_elixir_type(_value), do: nil
end
