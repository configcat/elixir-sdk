defmodule ConfigCat.API do
  @moduledoc false

  use HTTPoison.Base

  @impl HTTPoison.Base
  def process_request_headers(headers) do
    [{"Accept", "application/json"} | headers]
  end
end
