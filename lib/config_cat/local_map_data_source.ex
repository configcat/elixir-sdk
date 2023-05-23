defmodule ConfigCat.LocalMapDataSource do
  @moduledoc """
  Use flag overrides from a provided `Map`.

  See `ConfigCat.OverrideDataSource` for more details.
  """

  alias ConfigCat.Config
  alias ConfigCat.Constants
  alias ConfigCat.OverrideDataSource

  require ConfigCat.Constants
  require Logger

  defstruct [:override_behaviour, :settings]

  @type t :: %__MODULE__{
          override_behaviour: OverrideDataSource.behaviour(),
          settings: Config.t()
        }

  @doc """
  Create a `ConfigCat.OverrideDataSource` from a map of flag/value pairs.
  """
  @spec new(map, OverrideDataSource.behaviour()) :: t
  def new(overrides, override_behaviour) do
    flags =
      overrides
      |> Enum.map(fn {key, value} -> {key, %{Constants.value() => value}} end)
      |> Map.new()

    %__MODULE__{
      override_behaviour: override_behaviour,
      settings: %{Constants.feature_flags() => flags}
    }
  end

  defimpl OverrideDataSource do
    alias ConfigCat.LocalMapDataSource

    @spec behaviour(LocalMapDataSource.t()) :: OverrideDataSource.behaviour()
    def behaviour(%{override_behaviour: behaviour}), do: behaviour

    @spec overrides(LocalMapDataSource.t()) :: {:ok, Config.t()}
    def overrides(%{settings: settings}), do: {:ok, settings}
  end
end
