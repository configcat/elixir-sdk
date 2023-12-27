defmodule ConfigCat.Config do
  @moduledoc """
  Defines configuration-related types used in the rest of the library.
  """
  alias ConfigCat.Config.Preferences
  alias ConfigCat.Config.Segment
  alias ConfigCat.Config.Setting

  @typedoc false
  @type comparator :: non_neg_integer()

  @typedoc "The name of a configuration setting."
  @type key :: String.t()

  @typedoc false
  @type opt :: {:preferences, Preferences.t()} | {:settings, settings()}

  @typedoc false
  @type settings :: %{String.t() => Setting.t()}

  @typedoc "A collection of feature flags and preferences."
  @type t :: %{String.t() => map()}

  @typedoc false
  @type url :: String.t()

  @typedoc "The actual value of a configuration setting."
  @type value :: String.t() | boolean() | number()

  @typedoc "The name of a variation being tested."
  @type variation_id :: String.t()

  @settings "f"
  @preferences "p"
  @segments "s"

  @doc false
  @spec new([opt]) :: t()
  def new(opts \\ []) do
    settings = Keyword.get(opts, :settings, %{})
    preferences = Keyword.get_lazy(opts, :preferences, &Preferences.new/0)

    %{@settings => settings, @preferences => preferences}
  end

  @doc false
  @spec preferences(t()) :: Preferences.t()
  def preferences(config) do
    Map.get_lazy(config, @preferences, &Preferences.new/0)
  end

  @doc false
  @spec segments(t()) :: [Segment.t()]
  def segments(config) do
    Map.get(config, @segments, [])
  end

  @doc false
  @spec settings(t()) :: settings()
  def settings(config) do
    Map.get(config, @settings, %{})
  end

  @doc false
  @spec fetch_settings(t()) :: {:ok, settings()} | {:error, :not_found}
  def fetch_settings(config) do
    case Map.fetch(config, @settings) do
      {:ok, settings} -> {:ok, settings}
      :error -> {:error, :not_found}
    end
  end

  @doc false
  @spec merge(left :: t(), right :: t()) :: t()
  def merge(left, right) do
    left_flags = settings(left)
    right_flags = settings(right)

    Map.put(left, @settings, Map.merge(left_flags, right_flags))
  end

  @doc false
  @spec inline_salt_and_segments(t()) :: t()
  def inline_salt_and_segments(config) do
    salt = config |> preferences() |> Preferences.salt()
    segments = segments(config)

    Map.update(
      config,
      @settings,
      %{},
      &Map.new(&1, fn {key, setting} -> {key, Setting.inline_salt_and_segments(setting, salt, segments)} end)
    )
  end
end
