defmodule ConfigCat.Config do
  @moduledoc """
  Defines configuration-related types used in the rest of the library.
  """

  @typedoc false
  @type comparator :: non_neg_integer()

  @typedoc "The name of a configuration setting."
  @type key :: String.t()

  @typedoc "A collection of configuration settings."
  @type t :: map()

  @typedoc "The actual value of a configuration setting."
  @type value :: String.t() | boolean() | number()

  @typedoc "The name of a variation being tested."
  @type variation_id :: String.t()
end
