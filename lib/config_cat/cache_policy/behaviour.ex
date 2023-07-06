defmodule ConfigCat.CachePolicy.Behaviour do
  @moduledoc false

  alias ConfigCat.CachePolicy
  alias ConfigCat.Config

  @type refresh_result :: CachePolicy.refresh_result()

  @callback get(ConfigCat.instance_id()) :: {:ok, Config.t()} | {:error, :not_found}
  @callback is_offline(ConfigCat.instance_id()) :: boolean()
  @callback set_offline(ConfigCat.instance_id()) :: :ok
  @callback set_online(ConfigCat.instance_id()) :: :ok
  @callback force_refresh(ConfigCat.instance_id()) :: refresh_result()
end
