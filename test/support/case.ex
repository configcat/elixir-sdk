defmodule ConfigCat.Case do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias ConfigCat.CachePolicy

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  @spec fixture_file(String.t()) :: String.t()
  def fixture_file(filename) do
    __ENV__.file
    |> Path.dirname()
    |> Path.join("fixtures/" <> filename)
  end

  @spec start_config_cat(String.t(), keyword) :: {:ok, GenServer.name()}
  def start_config_cat(sdk_key, options \\ []) do
    name = String.to_atom(UUID.uuid4())

    default_options = [
      fetch_policy: CachePolicy.lazy(cache_refresh_interval_seconds: 300),
      name: name,
      sdk_key: sdk_key
    ]

    with {:ok, _pid} <- start_supervised({ConfigCat, Keyword.merge(default_options, options)}, id: name) do
      {:ok, name}
    end
  end
end