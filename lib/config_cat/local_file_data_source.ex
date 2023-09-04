defmodule ConfigCat.LocalFileDataSource do
  @moduledoc """
  Load flag overrides from a file.

  See `ConfigCat.OverrideDataSource` for more details.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.OverrideDataSource

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger

  defmodule FileCache do
    @moduledoc false

    use Agent
    use TypedStruct

    typedstruct do
      field :cached_timestamp, non_neg_integer(), default: 0
      field :settings, Config.settings()
    end

    @spec start_link(GenServer.options()) :: Agent.on_start()
    def start_link(_opts) do
      Agent.start_link(fn -> %__MODULE__{} end)
    end

    @spec cached_settings(Agent.agent()) :: {:ok, Config.t()} | {:error, :not_found}
    def cached_settings(cache) do
      case Agent.get(cache, fn %__MODULE__{settings: settings} -> settings end) do
        nil -> {:error, :not_found}
        settings -> {:ok, settings}
      end
    end

    @spec cached_timestamp(Agent.agent()) :: integer()
    def cached_timestamp(cache) do
      Agent.get(cache, fn %__MODULE__{cached_timestamp: timestamp} -> timestamp end)
    end

    @spec update(Agent.agent(), Config.t(), integer()) :: :ok
    def update(cache, settings, timestamp) do
      Agent.update(cache, fn %__MODULE__{} = state ->
        %{state | cached_timestamp: timestamp, settings: settings}
      end)
    end
  end

  typedstruct enforce: true do
    field :cache, pid()
    field :filename, String.t()
    field :override_behaviour, OverrideDataSource.behaviour()
  end

  @doc """
  Create a `ConfigCat.OverrideDataSource` that loads overrides from a file.
  """
  @spec new(String.t(), OverrideDataSource.behaviour()) :: t
  def new(filename, override_behaviour) do
    unless File.exists?(filename) do
      ConfigCatLogger.error("The file #{filename} does not exist.")
    end

    {:ok, pid} = FileCache.start_link([])

    %__MODULE__{cache: pid, filename: filename, override_behaviour: override_behaviour}
  end

  defimpl OverrideDataSource do
    alias ConfigCat.LocalFileDataSource

    require ConfigCat.Constants, as: Constants

    @spec behaviour(LocalFileDataSource.t()) :: OverrideDataSource.behaviour()
    def behaviour(data_source), do: data_source.override_behaviour

    @spec overrides(LocalFileDataSource.t()) :: Config.settings()
    def overrides(%{cache: cache} = data_source) do
      refresh_cache(cache, data_source.filename)

      case FileCache.cached_settings(cache) do
        {:ok, settings} -> settings
        _ -> %{}
      end
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
      ConfigCatLogger.error(
        "Could not decode json from file #{filename}. #{Exception.message(error)}"
      )
    end

    defp log_error({:error, error}, filename) do
      ConfigCatLogger.error(
        "Could not read the content of the file #{filename}. #{:file.format_error(error)}"
      )
    end

    defp normalize(%{"flags" => source} = _data) do
      source
      |> Enum.map(fn {key, value} -> {key, %{Constants.value() => value}} end)
      |> Map.new()
    end

    defp normalize(source) do
      case Config.fetch_settings(source) do
        {:ok, settings} -> settings
        _ -> %{}
      end
    end
  end
end
