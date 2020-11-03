defmodule ConfigCat.API do
  @moduledoc false

  use HTTPoison.Base

  def process_request_headers(headers) do
    [{"Accept", "application/json"} | headers]
  end

  def process_response_body(""), do: ""

  def process_response_body(body) do
    with {:ok, parsed} <- Jason.decode(body) do
      parsed
    else
      _ -> body
    end
  end
end
