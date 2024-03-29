defmodule ConfigCat.ConfigCache do
  @moduledoc """
  Defines a configuration cache.

  A calling application can optionally supply its own cache implementation to use
  in place of the default in-memory cache by providing the implementation's module name
  as the `:cache` option in `ConfigCat.child_spec/1`.

  The provided implementation must explicitly or implicitly implement this behaviour.

  If the cache implementation is a GenServer or similar, it is the calling
  application's responsibility to add it to its own supervision tree.
  """

  @typedoc "The cache key under which the configuration is stored"
  @type key :: String.t()

  @typedoc "The result of a cache fetch."
  @type result :: {:ok, String.t()} | {:error, :not_found}

  @doc """
  Fetches the serialized configuration stored under the given cache key.

  Returns `{:ok, serialized_config}` if there is a cached configuration or
  `{:error, :not_found}` if not.
  """
  @callback get(key) :: result()

  @doc """
  Stores an updated serialized configuration under the given cache key.

  Returns :ok.
  """
  @callback set(key, config :: String.t()) :: :ok | {:error, term()}
end
