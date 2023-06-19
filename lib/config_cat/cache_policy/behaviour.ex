defmodule ConfigCat.CachePolicy.Behaviour do
  @moduledoc false

  alias ConfigCat.CachePolicy
  alias ConfigCat.Config

  @type id :: CachePolicy.id()
  @type refresh_result :: CachePolicy.refresh_result()

  @callback get(id()) :: {:ok, Config.t()} | {:error, :not_found}
  @callback is_offline(id()) :: boolean()
  @callback set_offline(id()) :: :ok
  @callback set_online(id()) :: :ok
  @callback force_refresh(id()) :: refresh_result()
end
