defmodule ConfigCat.Config do
  @type key :: String.t()
  @type value :: String.t() | boolean() | number()
  @type variation_id :: String.t()
end
