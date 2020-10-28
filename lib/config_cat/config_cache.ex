defmodule ConfigCat.ConfigCache do
  @type key :: String.t()

  @callback get(key) :: {:ok, map()} | {:error, :not_found}
  @callback set(key, map()) :: :ok
end
