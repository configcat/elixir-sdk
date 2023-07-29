defmodule ConfigCat.ConfigEntry do
  @moduledoc false

  alias ConfigCat.Config

  defstruct config: %{}, etag: "", fetch_time_ms: 0, raw_config: "{}"

  @type t :: %__MODULE__{
          config: Config.t(),
          etag: String.t(),
          fetch_time_ms: non_neg_integer(),
          raw_config: String.t()
        }

  @spec new(Config.t(), String.t(), String.t()) :: t()
  def new(config, etag, raw_config) do
    %__MODULE__{
      config: config,
      etag: etag,
      fetch_time_ms: now(),
      raw_config: raw_config
    }
  end

  @spec new(Config.t(), String.t()) :: t()
  def new(config, etag) do
    %__MODULE__{
      config: config,
      etag: etag,
      fetch_time_ms: now(),
      raw_config: Jason.encode!(config)
    }
  end

  @spec now() :: non_neg_integer()
  def now, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)

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
        {:ok, config}

      {:error, error} ->
        {:error, "Invalid config JSON: #{config_json}. #{Exception.message(error)}"}
    end
  end

  @spec serialize(t()) :: String.t()
  def serialize(%__MODULE__{} = entry) do
    "#{trunc(entry.fetch_time_ms)}\n#{entry.etag}\n#{entry.raw_config}"
  end
end
