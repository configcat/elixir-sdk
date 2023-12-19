defmodule ConfigCat.Config do
  @moduledoc """
  Defines configuration-related types used in the rest of the library.
  """
  alias ConfigCat.Config.EvaluationFormula
  alias ConfigCat.Config.Preferences
  alias ConfigCat.Config.Segment

  @typedoc false
  @type comparator :: non_neg_integer()

  @typedoc false
  @type feature_flags :: %{String.t() => EvaluationFormula.t()}

  @typedoc "The name of a configuration setting."
  @type key :: String.t()

  @typedoc false
  @type opt :: {:feature_flags, feature_flags()} | {:preferences, Preferences.t()}

  @typedoc "A collection of feature flags and preferences."
  @type t :: %{String.t() => map()}

  @typedoc false
  @type url :: String.t()

  @typedoc "The actual value of a configuration setting."
  @type value :: String.t() | boolean() | number()

  @typedoc "The name of a variation being tested."
  @type variation_id :: String.t()

  @feature_flags "f"
  @preferences "p"
  @segments "s"

  @doc false
  @spec new([opt]) :: t()
  def new(opts \\ []) do
    feature_flags = Keyword.get(opts, :feature_flags, %{})
    preferences = Keyword.get_lazy(opts, :preferences, &Preferences.new/0)

    %{@feature_flags => feature_flags, @preferences => preferences}
  end

  @doc false
  @spec feature_flags(t()) :: feature_flags()
  def feature_flags(config) do
    Map.get(config, @feature_flags, %{})
  end

  @doc false
  @spec fetch_feature_flags(t()) :: {:ok, feature_flags()} | {:error, :not_found}
  def fetch_feature_flags(config) do
    case Map.fetch(config, @feature_flags) do
      {:ok, feature_flags} -> {:ok, feature_flags}
      :error -> {:error, :not_found}
    end
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
  @spec merge(left :: t(), right :: t()) :: t()
  def merge(left, right) do
    left_flags = feature_flags(left)
    right_flags = feature_flags(right)

    Map.put(left, @feature_flags, Map.merge(left_flags, right_flags))
  end
end
