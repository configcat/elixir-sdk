defmodule ConfigCat.RedirectMode do
  @moduledoc false

  @type t :: non_neg_integer()

  defmacro no_redirect, do: 0
  defmacro should_redirect, do: 1
  defmacro force_redirect, do: 2
end
