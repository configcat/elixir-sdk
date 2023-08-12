defmodule ConfigCat.Config do
  @moduledoc """
  Defines configuration-related types used in the rest of the library.
  """
  alias ConfigCat.RedirectMode

  @typedoc false
  @type comparator :: non_neg_integer()

  @typedoc "The name of a configuration setting."
  @type key :: String.t()

  @typedoc false
  @type settings :: map()

  @typedoc "A collection of configuration settings."
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
  @spec new_with_settings(settings()) :: t()
  def new_with_settings(settings) do
    %{@feature_flags => settings}
  end

  @doc false
  @spec fetch_settings(t()) :: {:ok, settings()} | {:error, :not_found}
  def fetch_settings(config) do
    case Map.fetch(config, @feature_flags) do
      {:ok, settings} -> {:ok, settings}
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
