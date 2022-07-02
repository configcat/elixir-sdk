defmodule ConfigCat.LocalFileDataSource do
  @moduledoc """
  Load flag overrides from a file.

  See `ConfigCat.OverrideDataSource` for more details.
  """

  alias ConfigCat.OverrideDataSource

  require Logger

  defstruct [:filename, :override_behaviour]

  def new(filename, override_behaviour) do
    unless File.exists?(filename) do
      Logger.error("The file #{filename} does not exist.")
    end

    %__MODULE__{filename: filename, override_behaviour: override_behaviour}
  end

  defimpl OverrideDataSource do
    alias ConfigCat.Constants

    require ConfigCat.Constants

    def behaviour(data_source), do: data_source.override_behaviour

    def overrides(%{filename: filename} = _data_source) do
      with {:ok, contents} <- File.read(filename),
           {:ok, data} <- Jason.decode(contents) do
        {:ok, normalize(data)}
      else
        error ->
          log_error(error, filename)
          {:error, :not_found}
      end
    end

    defp log_error({:error, %Jason.DecodeError{} = error}, filename) do
      Logger.error("Could not decode json from file #{filename}. #{Exception.message(error)}")
    end

    defp log_error({:error, error}, filename) do
      Logger.error(
        "Could not read the content of the file #{filename}. #{:file.format_error(error)}"
      )
    end

    defp normalize(%{"flags" => source} = _data) do
      flags =
        source
        |> Enum.map(fn {key, value} -> {key, %{Constants.value() => value}} end)
        |> Map.new()

      %{Constants.feature_flags() => flags}
    end

    defp normalize(source), do: source
  end
end
