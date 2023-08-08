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

  - `connect_timeout_milliseconds`: **OPTIONAL** timeout for establishing a TCP or SSL connection,
    in milliseconds. Default is 8000.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", connect_timeout_milliseconds: 8000]}
    ```

  - `data_governance`: **OPTIONAL** Describes the location of your feature flag
    and setting data within the ConfigCat CDN. This parameter needs to be in
    sync with your Data Governance preferences.  Defaults to `:global`. [More
    about Data Governance](https://configcat.com/docs/advanced/data-governance).

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", data_governance: :eu_only]}
    ```

  - `default_user`: **OPTIONAL** user object that will be used as fallback when
    there's no user parameter is passed to the getValue() method.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", default_user: User.new("test@test.com")]}
    ```

  - `flag_overrides`: **OPTIONAL** Specify a data source to use for [local flag
    overrides](https://configcat.com/docs/sdk-reference/elixir#flag-overrides).
    The data source must implement the `ConfigCat.OverrideDataSource` protocol.
    `ConfigCat.LocalFileDataSource` and `ConfigCat.LocalMapDataSource` are
    provided for you to use.

  - `http_proxy`: **OPTIONAL** Specify this option if you need to use a proxy
    server to access your ConfigCat settings. You can provide a simple URL, like
    `https://my_proxy.example.com` or include authentication information, like
    `https://user:password@my_proxy.example.com/`.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", http_proxy: "https://my_proxy.example.com"]}
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

  - `offline`: **OPTIONAL**  # Indicates whether the SDK should be initialized
    in offline mode or not.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", offline: true]}
    ```

  - `read_timeout_milliseconds`: **OPTIONAL** timeout for receiving an HTTP response from
    the socket, in milliseconds. Default is 5000.

    ```elixir
    {ConfigCat, [sdk_key: "YOUR SDK KEY", read_timeout_milliseconds: 5000]}
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

  alias ConfigCat.CachePolicy
  alias ConfigCat.Client
  alias ConfigCat.Config
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.OverrideDataSource
  alias ConfigCat.User

  require ConfigCat.Constants, as: Constants

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
          | {:connect_timeout_milliseconds, non_neg_integer()}
          | {:data_governance, data_governance()}
          | {:default_user, User.t()}
          | {:flag_overrides, OverrideDataSource.t()}
          | {:http_proxy, String.t()}
          | {:name, instance_id()}
          | {:offline, boolean()}
          | {:read_timeout_milliseconds, non_neg_integer()}
          | {:sdk_key, String.t()}

  @type options :: [option()]

  @typedoc "The return value of the `force_refresh/1` function."
  @type refresh_result :: :ok | {:error, term()}

  @typedoc "The actual value of a configuration setting."
  @type value :: Config.value()

  @typedoc "The name of a variation being tested."
  @type variation_id :: Config.variation_id()

  @doc """
  Builds a child specification to use in a Supervisor.

  Normally not called directly by your code. Instead, it will be
  called by your application's Supervisor once you add `ConfigCat`
  to its supervision tree.
  """
  @spec child_spec(options()) :: Supervisor.child_spec()
  defdelegate child_spec(options), to: ConfigCat.Supervisor

  @doc """
  Queries all settings keys in your configuration.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`,
    provide the `client: :unique_name` option, specifying the name you
    configured for the instance you want to access.
  """
  @spec get_all_keys([api_option()]) :: [key()]
  def get_all_keys(options \\ []) do
    options
    |> client()
    |> GenServer.call(:get_all_keys, Constants.fetch_timeout())
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
    options
    |> client()
    |> GenServer.call({:get_value, key, default_value, user}, Constants.fetch_timeout())
  end

  @doc "See `get_value_details/4`."
  @spec get_value_details(key(), value(), User.t() | [api_option()]) :: EvaluationDetails.t()
  def get_value_details(key, default_value, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_value_details(key, default_value, nil, user_or_options)
    else
      get_value_details(key, default_value, user_or_options, [])
    end
  end

  @doc """
  Fetches the value and evaluation details of a feature flag or setting.

  Retrieves the setting named `key` from your configuration. To use ConfigCat's
  [targeting](https://configcat.com/docs/advanced/targeting) feature, provide a
  `ConfigCat.User` struct containing the information used by the targeting
  rules.

  Returns the evaluation details for the setting, including the value. If an
  error occurs while performing the evaluation, it will be captured in the
  `:error` field of the `ConfigCat.EvaluationDetails` struct.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_value_details(key(), value(), User.t() | nil, [api_option()]) :: EvaluationDetails.t()
  def get_value_details(key, default_value, user, options) do
    options
    |> client()
    |> GenServer.call({:get_value_details, key, default_value, user}, Constants.fetch_timeout())
  end

  @doc "See `get_all_value_details/2`."
  @spec get_all_value_details(User.t() | [api_option()]) :: [EvaluationDetails.t()]
  def get_all_value_details(user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_all_value_details(nil, user_or_options)
    else
      get_all_value_details(user_or_options, [])
    end
  end

  @doc """
  Fetches the values and evaluation details of all feature flags and settings.

  To use ConfigCat's [targeting](https://configcat.com/docs/advanced/targeting)
  feature, provide a `ConfigCat.User` struct containing the information used by
  the targeting rules.

  Returns evaluation details for all settings and feature flags, including their
  values. If an error occurs while performing the evaluation, it will be
  captured in the `:error` field of the individual `ConfigCat.EvaluationDetails`
  structs.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec get_all_value_details(User.t() | nil, [api_option()]) :: [EvaluationDetails.t()]
  def get_all_value_details(user, options) do
    options
    |> client()
    |> GenServer.call({:get_all_value_details, user}, Constants.fetch_timeout())
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
    options
    |> client()
    |> GenServer.call({:get_key_and_value, variation_id}, Constants.fetch_timeout())
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
    options
    |> client()
    |> GenServer.call({:get_all_values, user}, Constants.fetch_timeout())
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
    options
    |> client()
    |> GenServer.call(:force_refresh, Constants.fetch_timeout())
  end

  @doc """
  Sets the default user.

  Returns `:ok`.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec set_default_user(User.t(), [api_option()]) :: :ok
  def set_default_user(user, options \\ []) do
    options
    |> client()
    |> GenServer.call({:set_default_user, user}, Constants.fetch_timeout())
  end

  @doc """
  Clears the default user.

  Returns `:ok`.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec clear_default_user([api_option()]) :: :ok
  def clear_default_user(options \\ []) do
    options
    |> client()
    |> GenServer.call(:clear_default_user, Constants.fetch_timeout())
  end

  @doc """
  Configures the SDK to allow HTTP requests.

  Returns `:ok`.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec set_online([api_option()]) :: :ok
  def set_online(options \\ []) do
    options
    |> client()
    |> GenServer.call(:set_online, Constants.fetch_timeout())
  end

  @doc """
  Configures the SDK to not initiate HTTP requests and work only from its cache.

  Returns `:ok`.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec set_offline([api_option()]) :: :ok
  def set_offline(options \\ []) do
    options
    |> client()
    |> GenServer.call(:set_offline, Constants.fetch_timeout())
  end

  @doc """
  Returns `true` when the SDK is configured not to initiate HTTP requests, otherwise `false`.

  ### Options

  - `client`: If you are running multiple instances of `ConfigCat`, provide the
    `client: :unique_name` option, specifying the name you configured for the
    instance you want to access.
  """
  @spec is_offline([api_option()]) :: boolean()
  def is_offline(options \\ []) do
    options
    |> client()
    |> GenServer.call(:is_offline, Constants.fetch_timeout())
  end

  defp client(options) do
    options
    |> Keyword.get(:client, __MODULE__)
    |> Client.via_tuple()
  end
end
