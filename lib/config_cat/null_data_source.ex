defmodule ConfigCat.NullDataSource do
  @moduledoc """
  Don't provide any local flag overrides.

  Used to avoid `is_nil` checks in the rest of the code.

  See `ConfigCat.OverrideDataSource` for more details.
  """

  alias ConfigCat.OverrideDataSource

  defstruct []

  @type t :: %__MODULE__{}

  @doc """
  Create a `ConfigCat.OverrideDataSource` that does nothing.
  """
  @spec new :: t
  def new do
    %__MODULE__{}
  end

  defimpl OverrideDataSource do
    def behaviour(_data_source), do: :local_over_remote
    def overrides(_data_source), do: {:ok, %{}}
  end
end
