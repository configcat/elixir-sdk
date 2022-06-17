defmodule ConfigCat do
  @moduledoc """
  The ConfigCat Elixir SDK.

  `ConfigCat` provides a `Supervisor` that must be added to your applications
  supervision tree and an API for accessing your ConfigCat settings.

  ## Add ConfigCat to Your Supervision Tree

  Your application's supervision tree might need to be different, but the most
  basic approach is to add `ConfigCat` as a child of your top-most supervisor.

  ```elixir
  # lib/my_app/application.ex
  def start(_type, _args) do
    children = [
      # ... other children ...
      {ConfigCat, [sdk_key: "YOUR SDK KEY"]}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

  If you need to run more than one instance of `ConfigCat`, you can add multiple
  `ConfigCat` children. You will need to give `ConfigCat` a unique `name` option
  for each, as well as using `Supervisor.child_spec/2` to provide a unique `id`
  for each instance.

  ```elixir
  # lib/my_app/application.ex
  def start(_type, _args) do
    children = [
      # ... other children ...
      Supervisor.child_spec({ConfigCat, [sdk_key: "sdk_key_1", name: :first]}, id: :config_cat_1),
      Supervisor.child_spec({ConfigCat, [sdk_key: "sdk_key_2", name: :second]}, id: :config_cat_2),
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

  ### Options

  `ConfigCat` takes a number of other keyword arguments:

  - `sdk_key`: **REQUIRED** The SDK key for accessing your ConfigCat settings.
    Go to the [Connect your application](https://app.configcat.com/sdkkey) tab
    to get your SDK key.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY"]}
    ```

  - `base_url`: **OPTIONAL** Allows you to specify a custom URL for fetching
    your ConfigCat settings.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", base_url: "https://my-cdn.example.com"]}
    ```

  - `cache`: **OPTIONAL** Custom cache implementation. By default, `ConfigCat`
    uses its own in-memory cache, but you can also provide the name of a module
    that implements the `ConfigCat.ConfigCache` behaviour if you want to provide
    your own cache (e.g. based on Redis). If your cache implementation requires
    supervision, it is your application's responsibility to provide that.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", cache: MyCustomCacheModule]}
    ```

  - `cache_policy`: **OPTIONAL** Specifies the [polling
    mode](https://configcat.com/docs/sdk-reference/elixir#polling-modes) used by
    `ConfigCat`. Defaults to auto-polling mode with a 60 second poll interval.
    You can specify a different polling mode or polling interval using
    `ConfigCat.CachePolicy.auto/1`, `ConfigCat.CachePolicy.lazy/1`, or
    `ConfigCat.CachePolicy.manual/0`.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", cache_policy: ConfigCat.CachePolicy.manual()]}
    ```

  - `data_governance`: **OPTIONAL** Describes the location of your feature flag
    and setting data within the ConfigCat CDN. This parameter needs to be in
    sync with your Data Governance preferences.  Defaults to `:global`. [More
    about Data Governance](https://configcat.com/docs/advanced/data-governance).

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", data_governance: :eu_only]}
    ```

  - `http_proxy`: **OPTIONAL** Specify this option if you need to use a proxy
    server to access your ConfigCat settings. You can provide a simple URL, like
    `https://my_proxy.example.com` or include authentication information, like
    `https://user:password@my_proxy.example.com/`.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", http_proxy: "https://my_proxy.example.com"]}
    ```

  - `connect_timeout`: **OPTIONAL** timeout for establishing a TCP or SSL connection,
    in milliseconds. Default is 8000.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", connect_timeout: 8000]}
    ```

  - `read_timeout`: **OPTIONAL** timeout for receiving an HTTP response from
    the socket, in milliseconds. Default is 5000

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", read_timeout: 5000]}
    ```

  - `name`: **OPTIONAL** A unique identifier for this instance of `ConfigCat`.
    Defaults to `ConfigCat`.  Must be provided if you need to run more than one
    instance of `ConfigCat` in the same application. If you provide a `name`,
    you must then pass that name to all of the API functions using the `client`
    option.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", name: :unique_name]}
    ```

    ```elixir
    ConfigCat.get_value("setting", "default", client: :unique_name)
    ```

  ## Use the API

  Once `ConfigCat` has been started as part of your application's supervision
  tree, you can use its API to access your settings.

  ```elixir
  ConfigCat.get_value("isMyAwesomeFeatureEnabled", false)
  ```

  By default, all of the public API functions will communicate with the default
  instance of the `ConfigCat` application.

  If you are running multiple instances of `ConfigCat`, you must provide the
  `client` option to the functions, passing along the unique name you specified
  above.

  ```elixir
  ConfigCat.get_value("isMyAwesomeFeatureEnabled", false, client: :second)
  ```
  """

  use Supervisor

  alias ConfigCat.{
    CacheControlConfigFetcher,
    CachePolicy,
    Client,
    Config,
    Constants,
    InMemoryCache,
    User
  }

  require Constants

  @typedoc "Options that can be passed to all API functions."
  @type api_option :: {:client, instance_id()}

  @typedoc """
  Data Governance mode

  [More about Data Governance](https://configcat.com/docs/advanced/data-governance)
  """
  @type data_governance :: :eu_only | :global

  @typedoc "Identifier of a specific instance of `ConfigCat`."
  @type instance_id :: atom()

  @typedoc "The name of a configuration setting."
  @type key :: Config.key()

  @typedoc "An option that can be provided when starting `ConfigCat`."
  @type option ::
          {:base_url, String.t()}
          | {:cache, module()}
          | {:cache_policy, CachePolicy.t()}
          | {:data_governance, data_governance()}
          | {:http_proxy, String.t()}
          | {:connect_timeout, Integer.t()}
          | {:read_timeout, Integer.t()}
          | {:name, instance_id()}
          | {:sdk_key, String.t()}

  @type options :: [option()]

  @typedoc "The return value of the `force_refresh/1` function."
  @type refresh_result :: :ok | {:error, term()}

  @typedoc "The actual value of a configuration setting."
  @type value :: Config.value()

  @typedoc "The name of a variation being tested."
  @type variation_id :: Config.variation_id()

  @default_cache InMemoryCache

  @doc """
  Starts an instance of `ConfigCat`.

  Normally not called directly by your code. Instead, it will be
  called by your application's Supervisor once you add `ConfigCat`
  to its supervision tree.
  """
  @spec start_link(options()) :: Supervisor.on_start()
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
      name: __MODULE__
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

  @doc """
  Queries all settings keys in your configuration.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`,
    provide the `client: :unique_name` option, specifying the name you
    configured for the instance you want to access.
  """
  @spec get_all_keys([api_option()]) :: [key()]
  def get_all_keys(options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_all_keys(client_name(name))
  end

  @doc "See `get_value/4`."
  @spec get_value(key(), value(), User.t() | [api_option()]) :: value()
  def get_value(key, default_value, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_value(key, default_value, nil, user_or_options)
    else
      get_value(key, default_value, user_or_options, [])
    end
  end

  @doc """
  Retrieves a setting value from your configuration.

  Retrieves the setting named `key` from your configuration. To use ConfigCat's
  [targeting](https://configcat.com/docs/advanced/targeting) feature, provide a
  `ConfigCat.User` struct containing the information used by the targeting
  rules.

  Returns the value of the setting, or `default_value` if an error occurs.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_value(key(), value(), User.t() | nil, [api_option()]) :: value()
  def get_value(key, default_value, user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_value(client_name(name), key, default_value, user)
  end

  @doc "See `get_variation_id/4`."
  @spec get_variation_id(key(), variation_id(), User.t() | [api_option()]) :: variation_id()
  def get_variation_id(key, default_variation_id, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_variation_id(key, default_variation_id, nil, user_or_options)
    else
      get_variation_id(key, default_variation_id, user_or_options, [])
    end
  end

  @doc """
  Retrieves the variation id for a setting from your configuration.

  Retrieves the setting named `key` from your configuration. To use ConfigCat's
  [targeting](https://configcat.com/docs/advanced/targeting) feature, provide a
  `ConfigCat.User` struct containing the information used by the targeting
  rules.

  Returns the variation id of the setting, or `default_variation_id` if an error
  occurs.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_variation_id(key(), variation_id(), User.t() | nil, [api_option()]) :: variation_id()
  def get_variation_id(key, default_variation_id, user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_variation_id(client_name(name), key, default_variation_id, user)
  end

  @doc "See `get_all_variation_ids/2`."
  @spec get_all_variation_ids(User.t() | [api_option()]) :: [variation_id()]
  def get_all_variation_ids(user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_all_variation_ids(nil, user_or_options)
    else
      get_all_variation_ids(user_or_options, [])
    end
  end

  @doc """
  Retrieves a list of all variation ids from your configuration.

  To use ConfigCat's [targeting](https://configcat.com/docs/advanced/targeting)
  feature, provide a `ConfigCat.User` struct containing the information used by
  the targeting rules.

  Returns a list of all variation ids.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_all_variation_ids(User.t() | nil, [api_option()]) :: [variation_id()]
  def get_all_variation_ids(user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_all_variation_ids(client_name(name), user)
  end

  @doc """
  Fetches the name and value of the setting corresponding to a variation id.

  Returns a tuple containing the setting name and value, or `nil` if an error
  occurs.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_key_and_value(variation_id(), [api_option()]) :: {key(), value()} | nil
  def get_key_and_value(variation_id, options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_key_and_value(client_name(name), variation_id)
  end

  @doc """
  Fetches the values of all feature flags or settings from your configuration.

  To use ConfigCat's [targeting](https://configcat.com/docs/advanced/targeting)
  feature, provide a `ConfigCat.User` struct containing the information used by
  the targeting rules.

  Returns a map of all key value pairs.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_all_values(User.t() | nil, [api_option()]) :: %{key() => value()}
  def get_all_values(user, options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_all_values(client_name(name), user)
  end

  @doc """
  Force a refresh of the configuration from ConfigCat's CDN.

  Depending on the polling mode you're using, `ConfigCat` may automatically
  fetch your configuration during normal operation. Call this function to
  force a manual refresh when you want one.

  If you are using manual polling mode (`ConfigCat.CachePolicy.manual/0`),
  this is the only way to fetch your configuration.

  Returns `:ok`.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
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
    |> Keyword.take([
      :base_url,
      :http_proxy,
      :connect_timeout,
      :read_timeout,
      :data_governance,
      :mode,
      :name,
      :sdk_key
    ])
  end
end
