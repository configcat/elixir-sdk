defmodule ConfigCat.ConfigCache do
  @moduledoc """
  Defines a configuration cache.

  A calling application can optionally supply its own cache implementation to use
  in place of the default in-memory cache by providing the implementation's module name
  as the `:cache` option in `ConfigCat.start_link/1`.

  The provided implementation must explicitly or implicitly implement this behaviour.

  If the cache implementation is a GenServer or similar, it is the calling
  application's responsibility to add it to its own supervision tree.
  """
  alias ConfigCat.Config

  @typedoc "The cache key under which the configuration is stored"
  @type key :: String.t()

  @typedoc "The result of a cache fetch."
  @type result :: {:ok, Config.t()} | {:error, :not_found}

  @doc """
  Fetches the configuration stored under the given cache key.

  Returns `{:ok, config}` if there is a cached configuration or
  `{:error, :not_found}` if not.
  """
  @callback get(key) :: result()

  @doc """
  Stores an updated configuration under the given cache key.

  Returns :ok.
  """
  @callback set(key, config :: Config.t()) :: :ok
end
