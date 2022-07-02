defmodule ConfigCat.LocalMapDataSource do
  @moduledoc """
  Use flag overrides from a provided `Map`.

  See `ConfigCat.OverrideDataSource` for more details.
  """

  alias ConfigCat.Constants
  alias ConfigCat.OverrideDataSource

  require ConfigCat.Constants
  require Logger

  defstruct [:override_behaviour, :settings]

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
    def behaviour(%{override_behaviour: behaviour}), do: behaviour
    def overrides(%{settings: settings}), do: {:ok, settings}
  end
end
