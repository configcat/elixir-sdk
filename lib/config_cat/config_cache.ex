defmodule ConfigCat.ConfigCache do
  alias ConfigCat.Config

  @type key :: String.t()
  @type result :: {:ok, Config.t()} | {:error, :not_found}

  @callback get(key) :: {:ok, Config.t()} | {:error, :not_found}
  @callback set(key, config :: Config.t()) :: :ok
end
