defmodule ConfigCat.API do
  use HTTPoison.Base

  def process_request_headers(headers) do
    version = Application.spec(:config_cat, :vsn) |> to_string()
    user_agent = "ConfigCat-Elixir/m-#{version}"

    [
      {"User-Agent", user_agent},
      {"X-ConfigCat-UserAgent", user_agent},
      {"Content-Type", "application/json"} | headers
    ]
  end
end
