defmodule ConfigCat.CachePolicy.Behaviour do
  @moduledoc false

  alias ConfigCat.{CachePolicy, Config}

  @type id :: CachePolicy.id()
  @type refresh_result :: CachePolicy.refresh_result()

  @callback get(id()) :: {:ok, Config.t()} | {:error, :not_found}
  @callback force_refresh(id()) :: refresh_result()
end
