defmodule ConfigCat.CachePolicy do
  @moduledoc """
  Represents the [polling mode](https://configcat.com/docs/sdk-reference/elixir#polling-modes) used by ConfigCat.

  The *ConfigCat SDK* supports 3 different polling mechanisms to
  acquire the setting values from *ConfigCat*. After the latest
  setting values are downloaded, they are stored in the internal
  cache and all requests are served from there.

  With the following polling modes, you can customize the SDK to
  best fit to your application's lifecycle.

  ## Auto polling (default)

  The *ConfigCat SDK* downloads the latest values and stores them
  automatically on a regular schedule.

  See `auto/1` below for details.

  ## Lazy loading

  When calling any of the public API functions (like `get_value()`),
  the *ConfigCat SDK* downloads the latest setting values if they are
  not present or have expired. In this case the function will wait
  until the settings have been fetched before returning.

  See `lazy/1` below for details.

  ## Manual polling

  Manual polling gives you full control over when the setting
  values are downloaded. *ConfigCat SDK* will not update them
  automatically. Calling `ConfigCat.force_refresh/1` is your
  application's responsibility.

  See `manual/0` below for details.
  """

  alias ConfigCat.CachePolicy.Auto
  alias ConfigCat.CachePolicy.Lazy
  alias ConfigCat.CachePolicy.Manual
  alias ConfigCat.ConfigCache
  alias ConfigCat.ConfigFetcher

  require ConfigCat.Constants, as: Constants

  @typedoc "Options for auto-polling mode."
  @type auto_options :: [
          {:on_changed, on_changed_callback()}
          | {:poll_interval_seconds, pos_integer()}
        ]

  @typedoc "Options for lazy-polling mode."
  @type lazy_options :: [{:cache_expiry_seconds, non_neg_integer()}]

  @typedoc "Callback to call when configuration changes."
  @type on_changed_callback :: (() -> :ok)

  @typedoc false
  @type option ::
          {:cache, module()}
          | {:cache_key, ConfigCache.key()}
          | {:cache_policy, t()}
          | {:fetcher, module()}
          | {:instance_id, ConfigCat.instance_id()}
          | {:offline, boolean()}

  @typedoc false
  @type options :: [option]

  @typedoc false
  @type refresh_result :: :ok | ConfigFetcher.fetch_error()

  @typedoc "The polling mode"
  @opaque t :: Auto.t() | Lazy.t() | Manual.t()

  @doc """
  Auto-polling mode.

  The *ConfigCat SDK* downloads the latest values and stores them
  automatically on a regular schedule.

  Use the `poll_interval_seconds` option to change the
  polling interval. Defaults to 60 seconds if not specified.

  ```elixir
  ConfigCat.CachePolicy.auto(poll_interval_seconds: 60)
  ```

  If you want your application to be notified whenever a new
  configuration is available, provide a 0-arity callback function
  using the `on_change` option.

  The `on_change` callback is called asynchronously (using `Task.start`).
  Any exceptions raised are caught and logged.

  ```elixir
  ConfigCat.CachePolicy.auto(on_changed: callback)
  ```
  """
  @spec auto(auto_options()) :: t()
  def auto(options \\ []) do
    Auto.new(options)
  end

  @doc """
  Lazy polling mode.

  When calling any of the public API functions (like `get_value()`),
  the *ConfigCat SDK* downloads the latest setting values if they are
  not present or have expired. In this case the function will wait
  until the settings have been fetched before returning.

  Use the required `cache_expiry_seconds` option to set the cache
  lifetime.

  ```elixir
  ConfigCat.CachePolicy.lazy(cache_expiry_seconds: 300)
  ```
  """
  @spec lazy(lazy_options()) :: t()
  def lazy(options) do
    Lazy.new(options)
  end

  @doc """
  Manual polling mode.

  Manual polling gives you full control over when the setting
  values are downloaded. *ConfigCat SDK* will not update them
  automatically. Calling `ConfigCat.force_refresh/1` is your
  application's responsibility.

  ```elixir
  ConfigCat.CachePolicy.manual()
  ```
  """
  @spec manual :: t()
  def manual do
    Manual.new()
  end

  @doc false
  @spec generate_cache_key(String.t()) :: String.t()
  def generate_cache_key(sdk_key) do
    key = "#{sdk_key}_#{Constants.config_filename()}_#{Constants.serialization_format_version()}"

    :crypto.hash(:sha, key)
    |> Base.encode16(case: :lower)
  end

  @doc false
  @spec policy_name(t()) :: module()
  def policy_name(%policy{}), do: policy

  @spec policy_name(options()) :: module()
  def policy_name(options) when is_list(options) do
    options
    |> Keyword.fetch!(:cache_policy)
    |> policy_name()
  end

  @doc false
  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(options) do
    policy_name(options).child_spec(options)
  end
end
