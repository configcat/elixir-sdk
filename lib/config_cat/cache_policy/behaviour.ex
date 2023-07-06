defmodule ConfigCat.CachePolicy.Behaviour do
  @moduledoc false

  alias ConfigCat.CachePolicy
  alias ConfigCat.CachePolicy.Behaviour
  alias ConfigCat.CachePolicy.Helpers
  alias ConfigCat.Config

  @type refresh_result :: CachePolicy.refresh_result()

  @callback get(ConfigCat.instance_id()) :: {:ok, Config.t()} | {:error, :not_found}
  @callback is_offline(ConfigCat.instance_id()) :: boolean()
  @callback set_offline(ConfigCat.instance_id()) :: :ok
  @callback set_online(ConfigCat.instance_id()) :: :ok
  @callback force_refresh(ConfigCat.instance_id()) :: refresh_result()

  defmacro __using__(_opts) do
    quote location: :keep do
      require ConfigCat.Constants, as: Constants

      @behaviour Behaviour

      @spec start_link(CachePolicy.options()) :: GenServer.on_start()
      def start_link(options) do
        Helpers.start_link(__MODULE__, options)
      end

      @impl Behaviour
      def get(instance_id) do
        instance_id
        |> via_tuple()
        |> GenServer.call(:get, Constants.fetch_timeout())
      end

      @impl Behaviour
      def is_offline(instance_id) do
        instance_id
        |> via_tuple()
        |> GenServer.call(:is_offline, Constants.fetch_timeout())
      end

      @impl Behaviour
      def set_offline(instance_id) do
        instance_id
        |> via_tuple()
        |> GenServer.call(:set_offline, Constants.fetch_timeout())
      end

      @impl Behaviour
      def set_online(instance_id) do
        instance_id
        |> via_tuple()
        |> GenServer.call(:set_online, Constants.fetch_timeout())
      end

      @impl Behaviour
      def force_refresh(instance_id) do
        instance_id
        |> via_tuple()
        |> GenServer.call(:force_refresh, Constants.fetch_timeout())
      end

      defp via_tuple(instance_id) do
        Helpers.via_tuple(__MODULE__, instance_id)
      end
    end
  end
end
