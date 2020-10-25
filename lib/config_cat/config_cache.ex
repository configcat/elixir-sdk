defmodule ConfigCat.ConfigCache do
  @type cache_key :: String.t()

  @callback get(cache_key) :: {:ok, map()} | {:error, :not_found}
  @callback set(cache_key, map()) :: :ok
end
