defmodule ConfigCat.CachePolicy.Behaviour do
  @moduledoc false

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.Config
  alias ConfigCat.FetchTime

  @callback get(ConfigCat.instance_id()) ::
              {:ok, Config.t(), FetchTime.t()} | {:error, :not_found}
  @callback offline?(ConfigCat.instance_id()) :: boolean()
  @callback set_offline(ConfigCat.instance_id()) :: :ok
  @callback set_online(ConfigCat.instance_id()) :: :ok
  @callback force_refresh(ConfigCat.instance_id()) :: ConfigCat.refresh_result()

  defmacro __using__(_opts) do
    quote location: :keep do
      @spec start_link(CachePolicy.options()) :: GenServer.on_start()
      def start_link(options) do
        Helpers.start_link(__MODULE__, options)
      end
    end
  end
end
