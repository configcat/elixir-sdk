defmodule ConfigCat.Supervisor do
  @moduledoc false

  use Supervisor

  alias ConfigCat.CacheControlConfigFetcher
  alias ConfigCat.CachePolicy
  alias ConfigCat.Client
  alias ConfigCat.Constants
  alias ConfigCat.InMemoryCache
  alias ConfigCat.NullDataSource
  alias ConfigCat.OverrideDataSource

  require Constants

  @default_cache InMemoryCache

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) when is_list(options) do
    sdk_key = options[:sdk_key]
    validate_sdk_key(sdk_key)

    options =
      default_options()
      |> Keyword.merge(options)
      |> generate_cache_key(sdk_key)

    name = Keyword.fetch!(options, :name)
    Supervisor.start_link(__MODULE__, options, name: name)
  end

  defp validate_sdk_key(nil), do: raise(ArgumentError, "SDK Key is required")
  defp validate_sdk_key(""), do: raise(ArgumentError, "SDK Key is required")
  defp validate_sdk_key(sdk_key) when is_binary(sdk_key), do: :ok

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
    fetcher_options = fetcher_options(options)

    policy_options =
      options
      |> Keyword.put(:fetcher_id, fetcher_options[:name])
      |> cache_policy_options()

    client_options =
      options
      |> Keyword.put(:cache_policy_id, policy_options[:name])
      |> client_options()

    override_behaviour = OverrideDataSource.behaviour(options[:flag_overrides])

    children =
      [
        default_cache(options),
        config_fetcher(fetcher_options, override_behaviour),
        cache_policy(policy_options, override_behaviour),
        {Client, client_options}
      ]
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp default_cache(options) do
    case Keyword.get(options, :cache) do
      @default_cache -> {@default_cache, cache_options(options)}
      _ -> nil
    end
  end

  defp config_fetcher(_options, :local_only), do: nil

  defp config_fetcher(options, _override_behaviour) do
    {CacheControlConfigFetcher, options}
  end

  defp cache_policy(_options, :local_only), do: nil

  defp cache_policy(options, _override_behaviour) do
    {CachePolicy, options}
  end

  @spec client_name(atom()) :: atom()
  def client_name(name), do: :"#{name}.Client"

  defp cache_policy_name(name), do: :"#{name}.CachePolicy"
  defp fetcher_name(name), do: :"#{name}.ConfigFetcher"

  defp generate_cache_key(options, sdk_key) do
    prefix =
      case Keyword.get(options, :cache) do
        @default_cache -> options[:name]
        _ -> "elixir_"
      end

    cache_key =
      :crypto.hash(:sha, "#{prefix}_#{ConfigCat.Constants.config_filename()}_#{sdk_key}")
      |> Base.encode16()

    Keyword.put(options, :cache_key, cache_key)
  end

  defp cache_options(options) do
    Keyword.take(options, [:cache_key])
  end

  defp cache_policy_options(options) do
    options
    |> Keyword.update!(:name, &cache_policy_name/1)
    |> Keyword.take([:cache, :cache_key, :cache_policy, :fetcher_id, :name, :offline])
  end

  defp client_options(options) do
    options
    |> Keyword.update!(:name, &client_name/1)
    |> Keyword.update!(:cache_policy, &CachePolicy.policy_name/1)
    |> Keyword.take([
      :cache_policy,
      :cache_policy_id,
      :default_user,
      :flag_overrides,
      :name
    ])
  end

  defp fetcher_options(options) do
    options
    |> Keyword.update!(:name, &fetcher_name/1)
    |> Keyword.put(:mode, options[:cache_policy].mode)
    |> Keyword.take([
      :base_url,
      :http_proxy,
      :connect_timeout_milliseconds,
      :read_timeout_milliseconds,
      :data_governance,
      :mode,
      :name,
      :sdk_key
    ])
  end
end
