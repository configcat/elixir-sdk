defmodule ConfigCat.CachePolicy.Behaviour do
  alias ConfigCat.{CachePolicy, Config, ConfigFetcher}

  @type id :: CachePolicy.id()
  @type refresh_result :: :ok | ConfigFetcher.fetch_error()

  @callback get(id()) :: {:ok, Config.t()} | {:error, :not_found}
  @callback force_refresh(id()) :: refresh_result()
end
