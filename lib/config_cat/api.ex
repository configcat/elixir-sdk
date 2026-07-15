defmodule ConfigCat.API do
  @moduledoc false
  @callback get(binary(), [{binary(), binary()}], Keyword.t()) :: {:ok, struct()} | {:error, struct()}
end

defmodule ConfigCat.API.Impl do
  @moduledoc false
  @behaviour ConfigCat.API

  @impl ConfigCat.API
  def get(url, headers, options) do
    req = Req.new(decode_body: false, headers: headers, url: url)

    options
    |> Enum.reduce(req, &apply_option/2)
    |> Req.get()
  end

  defp apply_option({:proxy, nil}, req), do: req

  defp apply_option({:proxy, url}, req) do
    uri = URI.parse(url)

    req
    |> Req.merge(
      connect_options: [
        proxy: {String.to_existing_atom(uri.scheme), uri.host, uri.port, []}
      ]
    )
    |> add_userinfo(uri.userinfo)
  end

  defp apply_option({:recv_timeout, timeout}, req) do
    Req.merge(req, receive_timeout: timeout)
  end

  defp apply_option({:timeout, timeout}, req) do
    Req.merge(req, connect_options: [timeout: timeout])
  end

  defp apply_option(_unused, req), do: req

  defp add_userinfo(req, nil), do: req

  defp add_userinfo(req, userinfo) do
    Req.merge(req,
      connect_options: [
        proxy_headers: {"proxy-authorization", "Basic " <> Base.encode64(userinfo)}
      ]
    )
  end
end
