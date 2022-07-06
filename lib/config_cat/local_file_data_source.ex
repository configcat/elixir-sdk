defmodule ConfigCat.LocalFileDataSource do
  @moduledoc """
  Load flag overrides from a file.

  See `ConfigCat.OverrideDataSource` for more details.
  """

  alias ConfigCat.OverrideDataSource

  require Logger

  defmodule FileCache do
    use Agent

    defstruct cached_timestamp: 0, settings: nil

    def start_link(_opts) do
      Agent.start_link(fn -> %__MODULE__{} end)
    end

    def cached_settings(cache) do
      case Agent.get(cache, fn %__MODULE__{settings: settings} -> settings end) do
        nil -> {:error, :not_found}
        settings -> {:ok, settings}
      end
    end

    def cached_timestamp(cache) do
      Agent.get(cache, fn %__MODULE__{cached_timestamp: timestamp} -> timestamp end)
    end

    def update(cache, settings, timestamp) do
      Agent.update(cache, fn %__MODULE__{} = state ->
        %{state | cached_timestamp: timestamp, settings: settings}
      end)
    end
  end

  defstruct [:cache, :filename, :override_behaviour]

  def new(filename, override_behaviour) do
    unless File.exists?(filename) do
      Logger.error("The file #{filename} does not exist.")
    end

    {:ok, pid} = FileCache.start_link([])

    %__MODULE__{cache: pid, filename: filename, override_behaviour: override_behaviour}
  end

  defimpl OverrideDataSource do
    alias ConfigCat.Constants

    require ConfigCat.Constants

    def behaviour(data_source), do: data_source.override_behaviour

    def overrides(%{cache: cache} = data_source) do
      refresh_cache(cache, data_source.filename)
      FileCache.cached_settings(cache)
    end

    defp refresh_cache(cache, filename) do
      with {:ok, %{mtime: timestamp}} <- File.stat(filename, time: :posix) do
        unless FileCache.cached_timestamp(cache) == timestamp do
          with {:ok, contents} <- File.read(filename),
               {:ok, data} <- Jason.decode(contents),
               settings <- normalize(data) do
            FileCache.update(cache, settings, timestamp)
          else
            error ->
              log_error(error, filename)
              :ok
          end
        end
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
