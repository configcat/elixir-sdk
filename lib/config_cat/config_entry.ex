defmodule ConfigCat.ConfigEntry do
  @moduledoc false

  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.FetchTime

  typedstruct enforce: true do
    field :config, Config.t(), default: %{}
    field :etag, String.t(), default: ""
    field :fetch_time_ms, FetchTime.t(), default: 0
    field :raw_config, String.t(), default: "{}"
  end

  @spec new(Config.t(), String.t(), String.t()) :: t()
  def new(config, etag, raw_config) do
    %__MODULE__{
      config: config,
      etag: etag,
      fetch_time_ms: FetchTime.now_ms(),
      raw_config: raw_config
    }
  end

  @spec new(Config.t(), String.t()) :: t()
  def new(config, etag) do
    %__MODULE__{
      config: config,
      etag: etag,
      fetch_time_ms: FetchTime.now_ms(),
      raw_config: Jason.encode!(config)
    }
  end

  @spec refresh(t()) :: t()
  def refresh(%__MODULE__{} = entry) do
    %{entry | fetch_time_ms: FetchTime.now_ms()}
  end

  @spec deserialize(String.t()) :: {:ok, t()} | {:error, String.t()}
  def deserialize(str) do
    with {:ok, [fetch_time_str, etag, raw_config]} <- parse(str),
         {:ok, fetch_time_ms} <- parse_fetch_time(fetch_time_str),
         :ok <- validate_etag(etag),
         {:ok, config} <- parse_config(raw_config) do
      {:ok,
       %__MODULE__{
         config: config,
         etag: etag,
         fetch_time_ms: fetch_time_ms,
         raw_config: raw_config
       }}
    end
  end

  defp parse(str) do
    case String.split(str, "\n", parts: 3) do
      parts when length(parts) == 3 -> {:ok, parts}
      _ -> {:error, "Number of values is fewer than expected"}
    end
  end

  defp parse_fetch_time(str) do
    case Integer.parse(str) do
      {ms, ""} -> {:ok, ms}
      _ -> {:error, "Invalid fetch time: #{str}"}
    end
  end

  defp validate_etag(""), do: {:error, "Empty eTag value"}
  defp validate_etag(_), do: :ok

  defp parse_config(config_json) do
    case Jason.decode(config_json) do
      {:ok, config} ->
        {:ok, Config.inline_salt_and_segments(config)}

      {:error, error} ->
        {:error, "Invalid config JSON: #{config_json}. #{Exception.message(error)}"}
    end
  end

  @spec serialize(t()) :: String.t()
  def serialize(%__MODULE__{} = entry) do
    "#{trunc(entry.fetch_time_ms)}\n#{entry.etag}\n#{entry.raw_config}"
  end
end
