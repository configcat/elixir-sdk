defmodule ConfigCat do
  use Supervisor

  alias ConfigCat.Client

  def start_link(sdk_key, options \\ [])

  def start_link(nil, _options), do: raise(ArgumentError, "SDK Key is required")

  def start_link(sdk_key, options) do
    name = Keyword.get(options, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, [{:sdk_key, sdk_key} | options], name: name)
  end

  @impl Supervisor
  def init(options) do
    name = options[:name]

    children = [
      {Client, Keyword.merge(options, name: client_name(name))}
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

  def force_refresh(name \\ __MODULE__) do
    Client.force_refresh(client_name(name))
  end

  defp client_name(name), do: :"#{name}.Client"
end
