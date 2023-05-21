defmodule ConfigCat.API do
  @moduledoc false

  use HTTPoison.Base

  def process_request_headers(headers) do
    [{"Accept", "application/json"} | headers]
  end

  def process_response_body(""), do: ""

  def process_response_body(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> parsed
      _ -> body
    end
  end
end
