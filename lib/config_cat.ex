defmodule ConfigCat do
  alias ConfigCat.Client

  def start_link(sdk_key, options \\ []) do
    Client.start_link(sdk_key, options)
  end

  defdelegate get_all_keys(options \\ []), to: Client
  defdelegate get_value(key, default_value, user_or_options \\ []), to: Client
  defdelegate get_value(key, default_value, user, options), to: Client
  defdelegate get_variation_id(key, default_variation_id, user_or_options \\ []), to: Client
  defdelegate get_variation_id(key, default_variation_id, user, options), to: Client
  defdelegate force_refresh(client \\ __MODULE__), to: Client
end
