defmodule ConfigCat.API do
  @moduledoc false
  @callback get(binary(), [{binary(), binary()}], Keyword.t()) :: {:ok, struct()} | {:error, struct()}
end

defmodule ConfigCat.API.ReqAPI do
  @moduledoc false
  @behaviour ConfigCat.API

  alias Req.Request

  @impl ConfigCat.API
  def get(url, headers, options) do
    req = build_request(url, headers, options)
    Req.get(req)
  end

  @doc false
  @spec build_request(binary(), [{binary(), binary()}], Keyword.t()) :: Req.Request.t()
  def build_request(url, headers, options) do
    req = Req.new(decode_body: false, headers: headers, url: url)

    Enum.reduce(options, req, &apply_option/2)
  end

  defp apply_option({:proxy, nil}, req), do: req

  defp apply_option({:proxy, url}, req) do
    uri = URI.parse(url)
    proxy = {String.to_existing_atom(uri.scheme), uri.host, uri.port, []}

    req
    |> merge_connect_option(:proxy, proxy)
    |> add_userinfo(uri.userinfo)
  end

  defp apply_option({:recv_timeout, timeout}, req) do
    Request.put_option(req, :receive_timeout, timeout)
  end

  defp apply_option({:timeout, timeout}, req) do
    merge_connect_option(req, :timeout, timeout)
  end

  defp apply_option(_unused, req), do: req

  defp add_userinfo(req, nil), do: req

  defp add_userinfo(req, userinfo) do
    proxy_headers = {"proxy-authorization", "Basic " <> Base.encode64(userinfo)}
    merge_connect_option(req, :proxy_headers, proxy_headers)
  end

  defp merge_connect_option(req, key, value) do
    new_connect_options =
      req
      |> Request.get_option(:connect_options, [])
      |> Keyword.put(key, value)

    Request.put_option(req, :connect_options, new_connect_options)
  end
end
