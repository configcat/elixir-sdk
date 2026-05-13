defmodule ConfigCat.HTTPClient.HTTPoison do
  @moduledoc """
  Default `ConfigCat.HTTPClient` adapter built on
  [HTTPoison](https://hex.pm/packages/httpoison).

  HTTPoison is declared as an optional dependency, so applications that supply
  their own `:http_client` adapter do not need to pull it in. If neither
  HTTPoison nor a custom adapter is configured, calling `get/3` raises with
  instructions for the user.
  """

  @behaviour ConfigCat.HTTPClient

  @compile {:no_warn_undefined, [HTTPoison]}

  @timeout_reasons ~w(checkout_timeout timeout connect_timeout)a
  @transient_reasons @timeout_reasons ++ ~w(closed econnrefused nxdomain)a

  @impl ConfigCat.HTTPClient
  def get(url, headers, opts) do
    ensure_httpoison!()
    headers = [{"Accept", "application/json"} | headers]

    case HTTPoison.get(url, headers, opts) do
      {:ok, %{status_code: status, body: body, headers: response_headers}} ->
        {:ok, %{status: status, body: body, headers: response_headers}}

      {:error, %{reason: reason}} ->
        {:error, %{reason: reason, transient?: reason in @transient_reasons}}
    end
  end

  defp ensure_httpoison! do
    if Code.ensure_loaded?(HTTPoison) do
      :ok
    else
      raise ArgumentError, """
      #{inspect(__MODULE__)} requires the optional :httpoison dependency.

      Either add it to your deps:

          {:httpoison, "~> 2.0"}

      or provide your own HTTP client by passing `:http_client` to
      `ConfigCat.start_link/1`. See `ConfigCat.HTTPClient` for the behaviour.
      """
    end
  end
end
