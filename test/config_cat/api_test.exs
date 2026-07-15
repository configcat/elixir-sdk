defmodule ConfigCat.API.ReqAPITest do
  use ExUnit.Case, async: false

  alias ConfigCat.API.ReqAPI
  alias Req.Request

  @url "https://some.example.com"

  describe "request building" do
    test "includes URL" do
      request = ReqAPI.build_request(@url, [], [])

      assert URI.to_string(request.url) == @url
    end

    test "does not automatically decode the response body" do
      request = ReqAPI.build_request(@url, [], [])
      assert Request.get_option(request, :decode_body) == false
    end

    test "lowercases and includes provided headers" do
      user_agent = "Some-User-Agent"
      headers = [{"User-Agent", user_agent}]
      request = ReqAPI.build_request(@url, headers, [])

      assert Request.get_header(request, "user-agent") == [user_agent]
    end

    test "handles read timeout option" do
      timeout = 10
      request = ReqAPI.build_request(@url, [], recv_timeout: timeout)

      assert Request.get_option(request, :receive_timeout) == timeout
    end

    test "handles connection timeout option" do
      timeout = 15
      request = ReqAPI.build_request(@url, [], timeout: timeout)

      connect_options = Request.get_option(request, :connect_options, [])
      assert connect_options[:timeout] == timeout
    end

    test "handles simple proxy" do
      proxy_url = "https://example.com"
      request = ReqAPI.build_request(@url, [], proxy: proxy_url)

      connect_options = Request.get_option(request, :connect_options, [])
      assert connect_options[:proxy] == {:https, "example.com", 443, []}
    end

    test "handles proxy with custom port" do
      proxy_url = "https://example.com:1234"
      request = ReqAPI.build_request(@url, [], proxy: proxy_url)

      connect_options = Request.get_option(request, :connect_options, [])
      assert connect_options[:proxy] == {:https, "example.com", 1234, []}
    end

    test "handles proxy with username/password" do
      proxy_url = "https://user:pass@example.com"
      request = ReqAPI.build_request(@url, [], proxy: proxy_url)

      connect_options = Request.get_option(request, :connect_options, [])
      assert connect_options[:proxy] == {:https, "example.com", 443, []}
      assert {"proxy-authorization", "Basic " <> encoded_userinfo} = connect_options[:proxy_headers]
      assert Base.decode64!(encoded_userinfo) == "user:pass"
    end

    test "properly merges options" do
      receive_timeout = 8
      timeout = 12
      proxy_url = "https://user:pass@example.com:1234"
      request = ReqAPI.build_request(@url, [], proxy: proxy_url, recv_timeout: receive_timeout, timeout: timeout)

      connect_options = Request.get_option(request, :connect_options, [])
      assert Request.get_option(request, :receive_timeout) == receive_timeout
      assert connect_options[:timeout] == timeout
      assert connect_options[:proxy] == {:https, "example.com", 1234, []}
      assert {"proxy-authorization", "Basic " <> encoded_userinfo} = connect_options[:proxy_headers]
      assert Base.decode64!(encoded_userinfo) == "user:pass"
    end
  end
end
