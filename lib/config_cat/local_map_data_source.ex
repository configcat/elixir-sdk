defmodule ConfigCat.LocalMapDataSource do
  @moduledoc """
  Use flag overrides from a provided `Map`.

  See `ConfigCat.OverrideDataSource` for more details.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.Config.EvaluationFormula
  alias ConfigCat.OverrideDataSource

  typedstruct enforce: true do
    field :config, Config.t()
    field :override_behaviour, OverrideDataSource.behaviour()
  end

  @doc """
  Create a `ConfigCat.OverrideDataSource` from a map of flag/value pairs.
  """
  @spec new(map, OverrideDataSource.behaviour()) :: t
  def new(overrides, override_behaviour) do
    feature_flags =
      overrides
      |> Enum.map(fn {key, value} -> {key, EvaluationFormula.new(value: value)} end)
      |> Map.new()

    %__MODULE__{
      config: Config.new(feature_flags: feature_flags),
      override_behaviour: override_behaviour
    }
  end

  defimpl OverrideDataSource do
    alias ConfigCat.LocalMapDataSource

    @spec behaviour(LocalMapDataSource.t()) :: OverrideDataSource.behaviour()
    def behaviour(%{override_behaviour: behaviour}), do: behaviour

    @spec overrides(LocalMapDataSource.t()) :: Config.t()
    def overrides(%{config: config}), do: config
  end
end
