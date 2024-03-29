defmodule ConfigCat.Supervisor do
  @moduledoc false

  use Supervisor

  alias ConfigCat.Cache
  alias ConfigCat.CacheControlConfigFetcher
  alias ConfigCat.CachePolicy
  alias ConfigCat.Client
  alias ConfigCat.Hooks
  alias ConfigCat.InMemoryCache
  alias ConfigCat.NullDataSource
  alias ConfigCat.OverrideDataSource

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @default_cache InMemoryCache

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)
    sdk_key = options[:sdk_key]
    validate_sdk_key(sdk_key, options)
    ensure_unique_sdk_key(sdk_key)

    options = put_cache_key(options, sdk_key)

    # Rename name -> instance_id for everything downstream
    {instance_id, options} = Keyword.pop!(options, :name)
    options = Keyword.put(options, :instance_id, instance_id)

    Supervisor.start_link(__MODULE__, options, name: via_tuple(instance_id, sdk_key))
  end

  defp validate_sdk_key(nil, _options), do: raise(ArgumentError, "SDK Key is required")
  defp validate_sdk_key("", _options), do: raise(ArgumentError, "SDK Key is required")

  defp validate_sdk_key(sdk_key, options) when is_binary(sdk_key) do
    has_base_url? = !is_nil(options[:base_url])
    overrides = options[:flag_overrides]

    cond do
      OverrideDataSource.behaviour(overrides) == :local_only ->
        :ok

      sdk_key =~ ~r[^.{22}/.{22}$] ->
        :ok

      sdk_key =~ ~r[^configcat-sdk-1/.{22}/.{22}$] ->
        :ok

      has_base_url? and sdk_key =~ ~r[^configcat-proxy/.+$] ->
        :ok

      true ->
        raise ArgumentError, "SDK Key `#{sdk_key}` is invalid."
    end
  end

  defp validate_sdk_key(sdk_key, _options) do
    raise ArgumentError, "SDK Key `#{inspect(sdk_key)}` is invalid."
  end

  defp ensure_unique_sdk_key(sdk_key) do
    ConfigCat.Registry
    |> Registry.select([{{{__MODULE__, :"$1"}, :_, sdk_key}, [], [:"$1"]}])
    |> case do
      [] ->
        :ok

      [instance_id] ->
        message =
          "There is an existing ConfigCat instance for the specified SDK Key. " <>
            "No new instance will be created and the specified options are ignored. " <>
            "You can use the existing instance by passing `client: #{instance_id}` to the ConfigCat API functions. " <>
            "SDK Key: '#{sdk_key}'."

        ConfigCatLogger.warning(message, event_id: 3000)

        raise ArgumentError, message
    end
  end

  defp default_options,
    do: [
      cache: @default_cache,
      cache_policy: CachePolicy.auto(),
      flag_overrides: NullDataSource.new(),
      name: ConfigCat,
      offline: false
    ]

  defp put_cache_key(options, sdk_key) do
    Keyword.put(options, :cache_key, Cache.generate_key(sdk_key))
  end

  defp via_tuple(instance_id, sdk_key) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}, sdk_key}}
  end

  @impl Supervisor
  def init(options) do
    override_behaviour = OverrideDataSource.behaviour(options[:flag_overrides])

    children =
      Enum.reject(
        [
          hooks(options),
          cache(options),
          config_fetcher(options, override_behaviour),
          cache_policy(options, override_behaviour),
          client(options, override_behaviour)
        ],
        &is_nil/1
      )

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp hooks(options) do
    hooks_options = Keyword.take(options, [:hooks, :instance_id])
    {Hooks, hooks_options}
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

  defp client(options, override_behaviour) do
    cache_policy = if override_behaviour == :local_only, do: CachePolicy.Null, else: CachePolicy

    client_options =
      options
      |> Keyword.take([
        :default_user,
        :flag_overrides,
        :instance_id
      ])
      |> Keyword.put(:cache_policy, cache_policy)

    {Client, client_options}
  end
end
