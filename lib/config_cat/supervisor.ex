defmodule ConfigCat.Supervisor do
  @moduledoc false

  use Supervisor

  alias ConfigCat.Cache
  alias ConfigCat.CacheControlConfigFetcher
  alias ConfigCat.CachePolicy
  alias ConfigCat.Client
  alias ConfigCat.InMemoryCache
  alias ConfigCat.NullDataSource
  alias ConfigCat.OverrideDataSource

  @default_cache InMemoryCache

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) when is_list(options) do
    sdk_key = options[:sdk_key]
    validate_sdk_key(sdk_key)

    options =
      default_options()
      |> Keyword.merge(options)
      |> put_cache_key(sdk_key)

    # Rename name -> instance_id for everything downstream
    {instance_id, options} = Keyword.pop!(options, :name)
    options = Keyword.put(options, :instance_id, instance_id)

    Supervisor.start_link(__MODULE__, options, name: :"#{instance_id}.Supervisor")
  end

  defp validate_sdk_key(nil), do: raise(ArgumentError, "SDK Key is required")
  defp validate_sdk_key(""), do: raise(ArgumentError, "SDK Key is required")
  defp validate_sdk_key(sdk_key) when is_binary(sdk_key), do: :ok

  defp put_cache_key(options, sdk_key) do
    Keyword.put(options, :cache_key, Cache.generate_key(sdk_key))
  end

  defp default_options,
    do: [
      cache: @default_cache,
      cache_policy: CachePolicy.auto(),
      flag_overrides: NullDataSource.new(),
      name: ConfigCat,
      offline: false
    ]

  @impl Supervisor
  def init(options) do
    override_behaviour = OverrideDataSource.behaviour(options[:flag_overrides])

    children =
      [
        cache(options),
        config_fetcher(options, override_behaviour),
        cache_policy(options, override_behaviour),
        client(options)
      ]
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp cache(options) do
    cache_options = Keyword.take(options, [:cache, :cache_key, :instance_id])
    {Cache, cache_options}
  end

  defp config_fetcher(_options, :local_only), do: nil

  defp config_fetcher(options, _override_behaviour) do
    fetcher_options =
      options
      |> Keyword.put(:mode, options[:cache_policy].mode)
      |> Keyword.take([
        :base_url,
        :http_proxy,
        :connect_timeout_milliseconds,
        :read_timeout_milliseconds,
        :data_governance,
        :instance_id,
        :mode,
        :sdk_key
      ])

    {CacheControlConfigFetcher, fetcher_options}
  end

  defp cache_policy(_options, :local_only), do: nil

  defp cache_policy(options, _override_behaviour) do
    policy_options = Keyword.take(options, [:cache_policy, :instance_id, :offline])

    {CachePolicy, policy_options}
  end

  defp client(options) do
    client_options =
      options
      |> Keyword.take([
        :default_user,
        :flag_overrides,
        :instance_id
      ])

    {Client, client_options}
  end
end
