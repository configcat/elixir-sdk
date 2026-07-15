defmodule ConfigCat.API do
  @moduledoc false
  @callback get(binary(), [{binary(), binary()}], Keyword.t()) :: {:ok, struct()} | {:error, struct()}
end

defmodule ConfigCat.API.Impl do
  @moduledoc false
  @behaviour ConfigCat.API

  defdelegate get(url, headers, options), to: ConfigCat.API.HTTPoisonImpl
end

defmodule ConfigCat.API.HTTPoisonImpl do
  @moduledoc false
  use HTTPoison.Base

  @impl HTTPoison.Base
  def process_request_headers(headers) do
    [{"Accept", "application/json"} | headers]
  end
end
