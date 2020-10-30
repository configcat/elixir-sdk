defmodule ConfigCat.DataGovernance do
  @type eu_only :: 1
  @type global :: 0
  @type t :: global | eu_only

  @spec global :: global()
  defmacro global, do: 0

  @spec eu_only :: eu_only()
  defmacro eu_only, do: 1
end
