defmodule ConfigCat.Config do
  @type key :: String.t()
  # TODO: flesh this out
  @type t :: map()
  @type value :: String.t() | boolean() | number()
  @type variation_id :: String.t()
end
