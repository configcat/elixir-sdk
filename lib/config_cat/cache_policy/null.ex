defmodule ConfigCat.CachePolicy.Null do
  @moduledoc false

  # The CachePolicy that gets used in :local_only mode

  alias ConfigCat.CachePolicy.Behaviour

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  @behaviour Behaviour

  @impl Behaviour
  def get(_instance_id) do
    # Should never be called
    {:error, :not_found}
  end

  @impl Behaviour
  def offline?(_instance_id) do
    true
  end

  @impl Behaviour
  def set_offline(_instance_id) do
    :ok
  end

  @impl Behaviour
  def set_online(_instance_id) do
    ConfigCatLogger.warning(
      "Client is configured to use the `:local_only` override behavior, thus `set_online()` has no effect.",
      event_id: 3202
    )

    :ok
  end

  @impl Behaviour
  def force_refresh(_instance_id) do
    {:error,
     "The SDK uses the `:local_only` override behavior which prevents making HTTP requests."}
  end
end
