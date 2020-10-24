defmodule ConfigCat do
  use Supervisor

  alias ConfigCat.{Client, CacheControlConfigFetcher, FetchPolicy}

  def start_link(sdk_key, options \\ [])

  def start_link(nil, _options), do: raise(ArgumentError, "SDK Key is required")

  def start_link(sdk_key, options) do
    options =
      default_options()
      |> Keyword.merge(options)
      |> Keyword.put(:sdk_key, sdk_key)

    name = Keyword.get(options, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, options, name: name)
  end

  defp default_options, do: [api: ConfigCat.API, fetch_policy: FetchPolicy.auto()]

  @impl Supervisor
  def init(options) do
    fetcher_options = fetcher_options(options)

    client_options =
      options
      |> Keyword.put(:fetcher_id, fetcher_options[:name])
      |> client_options()

    children = [
      {CacheControlConfigFetcher, fetcher_options},
      {Client, client_options}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_all_keys(options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_all_keys(client_name(name))
  end

  def get_value(key, default_value, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_value(key, default_value, nil, user_or_options)
    else
      get_value(key, default_value, user_or_options, [])
    end
  end

  def get_value(key, default_value, user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_value(client_name(name), key, default_value, user)
  end

  def get_variation_id(key, default_variation_id, user_or_options \\ []) do
    if Keyword.keyword?(user_or_options) do
      get_variation_id(key, default_variation_id, nil, user_or_options)
    else
      get_variation_id(key, default_variation_id, user_or_options, [])
    end
  end

  def get_variation_id(key, default_variation_id, user, options) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.get_variation_id(client_name(name), key, default_variation_id, user)
  end

  def force_refresh(options \\ []) do
    name = Keyword.get(options, :client, __MODULE__)
    Client.force_refresh(client_name(name))
  end

  defp client_name(name), do: :"#{name}.Client"
  defp fetcher_name(name), do: :"#{name}.ConfigFetcher"

  defp client_options(options) do
    options
    |> Keyword.update!(:name, &client_name/1)
    |> Keyword.take([:fetcher_id, :fetch_policy, :name])
  end

  defp fetcher_options(options) do
    options
    |> Keyword.update!(:name, &fetcher_name/1)
    |> Keyword.put(:mode, FetchPolicy.mode(options[:fetch_policy]))
    |> Keyword.take([:api, :base_url, :http_proxy, :mode, :name, :sdk_key])
  end
end
