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
      field :feature_flags, Config.feature_flags()
    end

    @spec start_link(GenServer.options()) :: Agent.on_start()
    def start_link(_opts) do
      Agent.start_link(fn -> %__MODULE__{} end)
    end

    @spec cached_feature_flags(Agent.agent()) :: {:ok, Config.t()} | {:error, :not_found}
    def cached_feature_flags(cache) do
      case Agent.get(cache, fn %__MODULE__{feature_flags: feature_flags} -> feature_flags end) do
        nil -> {:error, :not_found}
        feature_flags -> {:ok, feature_flags}
      end
    end

    @spec cached_timestamp(Agent.agent()) :: integer()
    def cached_timestamp(cache) do
      Agent.get(cache, fn %__MODULE__{cached_timestamp: timestamp} -> timestamp end)
    end

    @spec update(Agent.agent(), Config.t(), integer()) :: :ok
    def update(cache, feature_flags, timestamp) do
      Agent.update(cache, fn %__MODULE__{} = state ->
        %{state | cached_timestamp: timestamp, feature_flags: feature_flags}
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
      ConfigCatLogger.error(
        "Cannot find the local config file '#{filename}'. This is a path that your application provided to the ConfigCat SDK by passing it to the `LocalFileDataSource.new()` function. Read more: https://configcat.com/docs/sdk-reference/elixir/#json-file",
        event_id: 1300
      )
    end

    {:ok, pid} = FileCache.start_link([])

    %__MODULE__{cache: pid, filename: filename, override_behaviour: override_behaviour}
  end

  defimpl OverrideDataSource do
    alias ConfigCat.LocalFileDataSource

    require ConfigCat.Constants, as: Constants

    @spec behaviour(LocalFileDataSource.t()) :: OverrideDataSource.behaviour()
    def behaviour(data_source), do: data_source.override_behaviour

    @spec overrides(LocalFileDataSource.t()) :: Config.feature_flags()
    def overrides(%{cache: cache} = data_source) do
      refresh_cache(cache, data_source.filename)

      case FileCache.cached_feature_flags(cache) do
        {:ok, feature_flags} -> feature_flags
        _ -> %{}
      end
    end

    defp refresh_cache(cache, filename) do
      with {:ok, %{mtime: timestamp}} <- File.stat(filename, time: :posix) do
        unless FileCache.cached_timestamp(cache) == timestamp do
          with {:ok, contents} <- File.read(filename),
               {:ok, data} <- Jason.decode(contents) do
            feature_flags = normalize(data)
            FileCache.update(cache, feature_flags, timestamp)
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
        "Failed to decode JSON from the local config file #{filename}. #{Exception.message(error)}",
        event_id: 2302
      )
    end

    defp log_error({:error, error}, filename) do
      ConfigCatLogger.error(
        "Failed to read the local config file '#{filename}'. #{:file.format_error(error)}",
        event_id: 1302
      )
    end

    defp normalize(%{"flags" => source} = _data) do
      source
      |> Enum.map(fn {key, value} -> {key, %{Constants.value() => value}} end)
      |> Map.new()
    end

    defp normalize(source) do
      Config.feature_flags(source)
    end
  end
end
