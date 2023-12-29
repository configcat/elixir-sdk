defmodule ConfigCat.Config.ValueError do
  @moduledoc false
  @enforce_keys [:message]
  defexception [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }
end
