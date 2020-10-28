defmodule ConfigCat do
  use Supervisor

  alias ConfigCat.{
    CacheControlConfigFetcher,
    CachePolicy,
    Client,
    Config,
    Constants,
    DataGovernance,
    InMemoryCache,
    User
  }

  require Constants

  @type api_option :: {:client, client()}
  @type client :: Client.client()
  @type key :: Config.key()
  @type option ::
          {:base_url, String.t()}
          | {:cache, module()}
          | {:cache_policy, CachePolicy.t()}
          | {:http_proxy, String.t()}
          | {:data_governance, DataGovernance.t()}
  @type options :: [option()]
  @type refresh_result :: Client.refresh_result()
  @type value :: Config.value()
  @type variation_id :: Config.variation_id()

  @default_cache InMemoryCache

  @spec start_link(String.t(), options()) :: Supervisor.on_start()
  def start_link(sdk_key, options \\ [])

  def start_link(nil, _options), do: raise(ArgumentError, "SDK Key is required")

  def start_link(sdk_key, options) when is_binary(sdk_key) and is_list(options) do
    options =
      default_options()
      |> Keyword.merge(options)
      |> generate_cache_key(sdk_key)
      |> Keyword.put(:sdk_key, sdk_key)

    name = Keyword.get(options, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, options, name: name)
  end

  defp default_options,
    do: [
      cache: @default_cache,
      cache_policy: CachePolicy.auto()
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

    children =
      [
        {CacheControlConfigFetcher, fetcher_options},
        {CachePolicy, policy_options},
        {Client, client_options}
      ]
      |> add_default_cache(options)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp add_default_cache(children, options) do
    case Keyword.get(options, :cache) do
      @default_cache -> [{@default_cache, cache_options(options)} | children]
      _ -> children
    end
  end

  @spec get_all_keys([api_option()]) :: [key()]
  def get_all_keys(options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_all_keys(client_name(name))
  end

  @spec get_value(key(), value(), User.t() | [api_option()]) :: value()
  def get_value(key, default_value, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_value(key, default_value, nil, user_or_options)
    else
      get_value(key, default_value, user_or_options, [])
    end
  end

  @spec get_value(key(), value(), User.t() | nil, [api_option()]) :: value()
  def get_value(key, default_value, user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_value(client_name(name), key, default_value, user)
  end

  @spec get_variation_id(key(), variation_id(), User.t() | [api_option()]) :: variation_id()
  def get_variation_id(key, default_variation_id, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_variation_id(key, default_variation_id, nil, user_or_options)
    else
      get_variation_id(key, default_variation_id, user_or_options, [])
    end
  end

  @spec get_variation_id(key(), variation_id(), User.t() | nil, [api_option()]) :: variation_id()
  def get_variation_id(key, default_variation_id, user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_variation_id(client_name(name), key, default_variation_id, user)
  end

  @spec get_all_variation_ids(User.t() | [api_option()]) :: [variation_id()]
  def get_all_variation_ids(user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_all_variation_ids(nil, user_or_options)
    else
      get_all_variation_ids(user_or_options, [])
    end
  end

  @spec get_all_variation_ids(User.t() | nil, [api_option()]) :: [variation_id()]
  def get_all_variation_ids(user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_all_variation_ids(client_name(name), user)
  end

  @spec get_key_and_value(variation_id(), [api_option()]) :: {key(), value()} | nil
  def get_key_and_value(variation_id, options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_key_and_value(client_name(name), variation_id)
  end

  @spec force_refresh([api_option()]) :: refresh_result()
  def force_refresh(options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.force_refresh(client_name(name))
  end

  defp cache_policy_name(name), do: :"#{name}.CachePolicy"
  defp client_name(name), do: :"#{name}.Client"
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
    |> Keyword.take([:cache, :cache_key, :cache_policy, :fetcher_id, :name])
  end

  defp client_options(options) do
    options
    |> Keyword.update!(:name, &client_name/1)
    |> Keyword.update!(:cache_policy, &CachePolicy.policy_name/1)
    |> Keyword.take([
      :cache_policy,
      :cache_policy_id,
      :name
    ])
  end

  defp fetcher_options(options) do
    options
    |> Keyword.update!(:name, &fetcher_name/1)
    |> Keyword.put(:mode, options[:cache_policy].mode)
    |> Keyword.take([:base_url, :http_proxy, :data_governance, :mode, :name, :sdk_key])
  end
end
