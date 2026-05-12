defmodule ConfigCat.HTTPClient do
  @moduledoc """
  Behaviour for the HTTP transport used by the ConfigCat SDK.

  The SDK ships with `ConfigCat.API`, a default adapter built on
  [HTTPoison](https://hex.pm/packages/httpoison). To plug in a different HTTP
  client (Finch, Req, Mint, Tesla, a test stub, ...) implement this behaviour
  and pass the module via the `:http_client` option to `ConfigCat.start_link/1`.

      defmodule MyApp.ConfigCatClient do
        @behaviour ConfigCat.HTTPClient

        @impl true
        def get(url, headers, opts) do
          # Translate to your favourite HTTP client and return a normalized
          # `{:ok, %{status: _, body: _, headers: _}}` or
          # `{:error, %{reason: _, transient?: _}}`.
        end
      end

      ConfigCat.start_link(sdk_key: "...", http_client: MyApp.ConfigCatClient)

  Adapters are responsible for classifying errors as transient (the SDK will
  treat them as retryable) or permanent.
  """

  @type header :: {String.t(), String.t()}
  @type url :: String.t()
  @type opts :: keyword()

  @type response :: %{
          required(:status) => 100..599,
          required(:body) => binary(),
          required(:headers) => [header()]
        }

  @type error :: %{
          required(:reason) => any(),
          required(:transient?) => boolean()
        }

  @callback get(url(), [header()], opts()) :: {:ok, response()} | {:error, error()}
end
