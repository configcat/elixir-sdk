defmodule ConfigCat.API do
  use HTTPoison.Base

  def process_request_headers(headers) do
    [{"Content-Type", "application/json"} | headers]
  end
end
