defmodule ConfigCat.LocalMapDataSource do
  @moduledoc """
  Use flag overrides from a provided `Map`.

  See `ConfigCat.OverrideDataSource` for more details.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.OverrideDataSource

  require ConfigCat.Constants, as: Constants
  require Logger

  typedstruct enforce: true do
    field :override_behaviour, OverrideDataSource.behaviour()
    field :settings, Config.settings()
  end

  @doc """
  Create a `ConfigCat.OverrideDataSource` from a map of flag/value pairs.
  """
  @spec new(map, OverrideDataSource.behaviour()) :: t
  def new(overrides, override_behaviour) do
    settings =
      overrides
      |> Enum.map(fn {key, value} -> {key, %{Constants.value() => value}} end)
      |> Map.new()

    %__MODULE__{
      override_behaviour: override_behaviour,
      settings: settings
    }
  end

  defimpl OverrideDataSource do
    alias ConfigCat.LocalMapDataSource

    @spec behaviour(LocalMapDataSource.t()) :: OverrideDataSource.behaviour()
    def behaviour(%{override_behaviour: behaviour}), do: behaviour

    @spec overrides(LocalMapDataSource.t()) :: Config.settings()
    def overrides(%{settings: settings}), do: settings
  end
end
