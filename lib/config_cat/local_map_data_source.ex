defmodule ConfigCat.LocalMapDataSource do
  @moduledoc """
  Use flag overrides from a provided `Map`.

  See `ConfigCat.OverrideDataSource` for more details.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.OverrideDataSource

  require ConfigCat.Constants, as: Constants

  typedstruct enforce: true do
    field :override_behaviour, OverrideDataSource.behaviour()
    field :feature_flags, Config.feature_flags()
  end

  @doc """
  Create a `ConfigCat.OverrideDataSource` from a map of flag/value pairs.
  """
  @spec new(map, OverrideDataSource.behaviour()) :: t
  def new(overrides, override_behaviour) do
    feature_flags =
      overrides
      |> Enum.map(fn {key, value} -> {key, %{Constants.value() => value}} end)
      |> Map.new()

    %__MODULE__{
      override_behaviour: override_behaviour,
      feature_flags: feature_flags
    }
  end

  defimpl OverrideDataSource do
    alias ConfigCat.LocalMapDataSource

    @spec behaviour(LocalMapDataSource.t()) :: OverrideDataSource.behaviour()
    def behaviour(%{override_behaviour: behaviour}), do: behaviour

    @spec overrides(LocalMapDataSource.t()) :: Config.feature_flags()
    def overrides(%{feature_flags: feature_flags}), do: feature_flags
  end
end
