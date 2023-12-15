defmodule ConfigCat.Config do
  @moduledoc """
  Defines configuration-related types used in the rest of the library.
  """
  alias ConfigCat.RedirectMode

  @typedoc false
  @type comparator :: non_neg_integer()

  @typedoc false
  @type feature_flags :: %{String.t() => map()}

  @typedoc "The name of a configuration setting."
  @type key :: String.t()

  @typedoc false
  @type opt :: {:feature_flags, feature_flags()}

  @typedoc "A collection of feature flags and preferences."
  @type t :: map()

  @typedoc false
  @type url :: String.t()

  @typedoc "The actual value of a configuration setting."
  @type value :: String.t() | boolean() | number()

  @typedoc "The name of a variation being tested."
  @type variation_id :: String.t()

  @feature_flags "f"
  @preferences "p"
  @preferences_base_url "u"
  @redirect_mode "r"

  @doc false
  @spec new([opt]) :: t()
  def new(opts \\ []) do
    feature_flags = Keyword.get(opts, :feature_flags, %{})

    %{@feature_flags => feature_flags}
  end

  @doc false
  @spec new_with_preferences(url(), RedirectMode.t()) :: t()
  def new_with_preferences(base_url, redirect_mode) do
    %{
      @preferences => %{
        @preferences_base_url => base_url,
        @redirect_mode => redirect_mode
      }
    }
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
  @spec preferences(t()) :: {url() | nil, RedirectMode.t() | nil}
  def preferences(config) do
    case config[@preferences] do
      nil -> {nil, nil}
      preferences -> {preferences[@preferences_base_url], preferences[@redirect_mode]}
    end
  end
end
