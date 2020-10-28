defmodule ConfigCat.DataGovernance do
  @type t :: global | eu_only

  @type eu_only :: integer()
  @type global :: integer()

  @spec global :: 0
  defmacro global, do: 0
  @spec eu_only :: 1
  defmacro eu_only, do: 1
end
