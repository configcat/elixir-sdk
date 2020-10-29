defmodule ConfigCat.Config do
  @type comparator :: non_neg_integer()
  @type key :: String.t()
  @type t :: map()
  @type value :: String.t() | boolean() | number()
  @type variation_id :: String.t()
end