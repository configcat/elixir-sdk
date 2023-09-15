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
  alias ConfigCat.CachePolicy.Behaviour
  alias ConfigCat.CachePolicy.Lazy
  alias ConfigCat.CachePolicy.Manual

  require ConfigCat.Constants, as: Constants

  @behaviour Behaviour

  @typedoc "Options for auto-polling mode."
  @type auto_options :: [
          {:max_init_wait_time_seconds, non_neg_integer()}
          | {:poll_interval_seconds, pos_integer()}
        ]

  @typedoc "Options for lazy-polling mode."
  @type lazy_options :: [{:cache_expiry_seconds, non_neg_integer()}]

  @typedoc "Callback to call when configuration changes."
  @type on_changed_callback :: (() -> :ok)

  @typedoc false
  @type option ::
          {:cache_policy, t()}
          | {:fetcher, module()}
          | {:instance_id, ConfigCat.instance_id()}
          | {:offline, boolean()}

  @typedoc false
  @type options :: [option]

  @typedoc "The polling mode"
  @opaque t :: Auto.t() | Lazy.t() | Manual.t()

  @doc """
  Auto-polling mode.

  The *ConfigCat SDK* downloads the latest values and stores them
  automatically on a regular schedule.

  Use the `max_init_wait_time_seconds` option to set the maximum waiting time
  between initialization and the first config acquisition. Defaults to 5 seconds
  if not specified.

  ```elixir
  ConfigCat.CachePolicy.auto(max_init_wait_time_seconds: 5)
  ```

  Use the `poll_interval_seconds` option to change the
  polling interval. Defaults to 60 seconds if not specified.

  ```elixir
  ConfigCat.CachePolicy.auto(poll_interval_seconds: 60)
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
  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(options) do
    %policy_module{} = Keyword.fetch!(options, :cache_policy)
    policy_module.child_spec(options)
  end

  @impl Behaviour
  def get(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:get, Constants.fetch_timeout())
  end

  @impl Behaviour
  def offline?(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:offline?, Constants.fetch_timeout())
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

  @doc false
  @spec via_tuple(ConfigCat.instance_id()) :: {:via, module(), term()}
  def via_tuple(instance_id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}}}
  end
end
