defmodule ConfigCat.API do
  use HTTPoison.Base

  def process_request_headers(headers) do
    [
      {"User-Agent", "ConfigCat-Elixir/m-0.0.1"},
      {"X-ConfigCat-UserAgent", "ConfigCat-Elixir/m-0.0.1"},
      {"Content-Type", "application/json"} | headers
    ]
  end
end
