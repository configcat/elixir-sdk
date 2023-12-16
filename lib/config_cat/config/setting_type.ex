defmodule ConfigCat.Config.SettingType do
  @moduledoc false

  @type t :: non_neg_integer()

  defmacro bool, do: 0
  defmacro string, do: 1
  defmacro int, do: 2
  defmacro double, do: 3
end
