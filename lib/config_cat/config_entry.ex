defmodule ConfigCat.ConfigEntry do
  @moduledoc false

  alias ConfigCat.Config

  defstruct config: %{}, etag: "", fetch_time: 0, raw_config: "{}"

  @type t :: %__MODULE__{
          config: Config.t(),
          etag: String.t(),
          fetch_time: non_neg_integer(),
          raw_config: String.t()
        }

  @spec new(Config.t(), String.t()) :: t()
  def new(config, etag) do
    %__MODULE__{
      config: config,
      etag: etag,
      fetch_time: now(),
      raw_config: Jason.encode!(config)
    }
  end

  @spec new(Config.t(), String.t(), String.t()) :: t()
  def new(config, etag, raw_config) do
    %__MODULE__{
      config: config,
      etag: etag,
      fetch_time: now(),
      raw_config: raw_config
    }
  end

  @spec now() :: non_neg_integer()
  def now, do: DateTime.utc_now() |> DateTime.to_unix()
end
