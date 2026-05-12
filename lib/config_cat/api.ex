defmodule ConfigCat.API do
  @moduledoc false

  @behaviour ConfigCat.HTTPClient

  @timeout_reasons ~w(checkout_timeout timeout connect_timeout)a
  @transient_reasons @timeout_reasons ++ ~w(closed econnrefused nxdomain)a

  @impl ConfigCat.HTTPClient
  def get(url, headers, opts) do
    headers = [{"Accept", "application/json"} | headers]

    case HTTPoison.get(url, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: status, body: body, headers: response_headers}} ->
        {:ok, %{status: status, body: body, headers: response_headers}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %{reason: reason, transient?: reason in @transient_reasons}}
    end
  end
end
