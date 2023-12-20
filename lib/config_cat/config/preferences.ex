defmodule ConfigCat.Config.Preferences do
  @moduledoc false
  alias ConfigCat.RedirectMode

  @type opt :: {:base_url, url()} | {:redirect_mode, RedirectMode.t()}
  @type salt :: String.t()
  @type t :: %{String.t() => term()}
  @type url :: String.t()

  @base_url "u"
  @redirect_mode "r"
  @salt "s"

  @spec new([opt]) :: t()
  def new(opts \\ []) do
    %{
      @base_url => opts[:base_url],
      @redirect_mode => opts[:redirect_mode]
    }
  end

  @spec base_url(t()) :: url() | nil
  def base_url(preferences) do
    Map.get(preferences, @base_url)
  end

  @spec redirect_mode(t()) :: RedirectMode.t() | nil
  def redirect_mode(preferences) do
    Map.get(preferences, @redirect_mode)
  end

  @spec salt(t()) :: salt()
  def salt(preferences) do
    Map.get(preferences, @salt, "")
  end
end
