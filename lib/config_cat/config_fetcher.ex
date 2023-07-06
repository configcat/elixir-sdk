defmodule ConfigCat.ConfigFetcher do
  @moduledoc false

  alias ConfigCat.Config
  alias HTTPoison.Error
  alias HTTPoison.Response

  @type fetch_error :: {:error, Error.t() | Response.t()}
  @type id :: atom()
  @type result :: {:ok, Config.t()} | {:ok, :unchanged} | fetch_error()

  @callback fetch(id()) :: result()

  defmodule RedirectMode do
    @moduledoc false

    defmacro no_redirect, do: 0
    defmacro should_redirect, do: 1
    defmacro force_redirect, do: 2
  end
end

defmodule ConfigCat.CacheControlConfigFetcher do
  @moduledoc false

  use GenServer

  alias ConfigCat.ConfigFetcher
  alias ConfigCat.Constants
  alias ConfigFetcher.RedirectMode
  alias HTTPoison.Response

  require Constants
  require RedirectMode
  require Logger

  @type option ::
          {:base_url, String.t()}
          | {:connect_timeout_milliseconds, non_neg_integer()}
          | {:data_governance, ConfigCat.data_governance()}
          | {:http_proxy, String.t()}
          | {:id, ConfigCat.instance_id()}
          | {:mode, String.t()}
          | {:read_timeout_milliseconds, non_neg_integer()}
          | {:sdk_key, String.t()}
  @type options :: [option]

  @behaviour ConfigFetcher

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    {id, options} = Keyword.pop!(options, :id)

    initial_state =
      default_options()
      |> Keyword.merge(options)
      |> choose_base_url()
      |> Map.new()
      |> Map.merge(%{etag: nil, redirects: %{}})

    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(id))
  end

  defp via_tuple(id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, id}}}
  end

  defp default_options,
    do: [
      api: ConfigCat.API,
      data_governance: :global,
      connect_timeout_milliseconds: 8000,
      read_timeout_milliseconds: 5000
    ]

  defp choose_base_url(options) do
    case Keyword.get(options, :base_url) do
      nil ->
        base_url = options |> Keyword.get(:data_governance) |> default_url()
        Keyword.merge(options, base_url: base_url, custom_endpoint?: false)

      _ ->
        Keyword.put(options, :custom_endpoint?, true)
    end
  end

  defp default_url(:eu_only), do: Constants.base_url_eu_only()
  defp default_url(_), do: Constants.base_url_global()

  @impl ConfigFetcher
  def fetch(fetcher_id) do
    fetcher_id
    |> via_tuple()
    |> GenServer.call(:fetch, Constants.fetch_timeout())
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:fetch, _from, state) do
    do_fetch(state)
  end

  defp do_fetch(state) do
    Logger.info("Fetching configuration from ConfigCat")

    with api <- Map.get(state, :api),
         {:ok, response} <-
           api.get(url(state), headers(state), http_options(state)) do
      response
      |> log_response()
      |> handle_response(state)
    else
      error ->
        log_error(error, state)
        {:reply, error, state}
    end
  end

  defp url(%{base_url: base_url, sdk_key: sdk_key}) do
    base_url
    |> URI.parse()
    |> URI.merge("#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}")
    |> URI.to_string()
  end

  defp headers(state) do
    base_headers(state) ++ cache_headers(state)
  end

  defp base_headers(%{mode: mode}) do
    version = Application.spec(:configcat, :vsn) |> to_string()
    user_agent = "ConfigCat-Elixir/#{mode}-#{version}"

    [
      {"User-Agent", user_agent},
      {"X-ConfigCat-UserAgent", user_agent}
    ]
  end

  defp cache_headers(state) do
    case Map.get(state, :etag) do
      nil -> []
      etag -> [{"If-None-Match", etag}]
    end
  end

  defp http_options(state) do
    options =
      Map.take(state, [:http_proxy, :connect_timeout_milliseconds, :read_timeout_milliseconds])

    Enum.map(options, fn
      {:http_proxy, value} -> {:proxy, value}
      {:connect_timeout_milliseconds, value} -> {:timeout, value}
      {:read_timeout_milliseconds, value} -> {:recv_timeout, value}
    end)
  end

  # This function is slightly complex, but still reasonably understandable.
  # Breaking it up doesn't seem like it will help much.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp handle_response(%Response{status_code: code, body: config, headers: headers}, state)
       when code >= 200 and code < 300 do
    with etag <- extract_etag(headers),
         %{base_url: new_base_url, custom_endpoint?: custom_endpoint?, redirects: redirects} <-
           state,
         p <- Map.get(config, Constants.preferences(), %{}),
         base_url <- Map.get(p, Constants.preferences_base_url()),
         redirect <- Map.get(p, Constants.redirect()) do
      followed? = Map.has_key?(redirects, new_base_url)

      new_state =
        cond do
          custom_endpoint? && redirect != RedirectMode.force_redirect() ->
            state

          redirect == RedirectMode.no_redirect() ->
            state

          base_url && !followed? ->
            {_, _, state} =
              do_fetch(%{
                state
                | base_url: base_url,
                  redirects: Map.put(redirects, base_url, 1)
              })

            state

          followed? ->
            Logger.warn(
              "Redirect loop during config.json fetch. Please contact support@configcat.com."
            )

            # redirects needs reset as customers might change their configs at any time.
            %{state | redirects: %{}}

          true ->
            state
        end

      if redirect == RedirectMode.should_redirect() do
        Logger.warn("""
        Your data_governance parameter at ConfigCat client initialization
        is not in sync with your preferences on the ConfigCat Dashboard:
        https://app.configcat.com/organization/data-governance.
        Only Organization Admins can set this preference.
        """)
      end

      {:reply, {:ok, config}, %{new_state | etag: etag}}
    end
  end

  defp handle_response(%Response{status_code: 304}, state) do
    {:reply, {:ok, :unchanged}, state}
  end

  defp handle_response(response, state) do
    {:reply, {:error, response}, state}
  end

  defp extract_etag(headers) do
    case List.keyfind(headers, "ETag", 0) do
      nil -> nil
      {_key, value} -> value
    end
  end

  defp log_response(%Response{headers: headers, status_code: status_code} = response) do
    Logger.info(
      "ConfigCat configuration json fetch response code: #{status_code} Cached: #{extract_etag(headers)}"
    )

    response
  end

  defp log_error(error, state) do
    Logger.error("Double-check your SDK Key at https://app.configcat.com/sdkkey.")
    Logger.error("Failed to fetch configuration from ConfigCat: #{inspect(error)}")

    case error do
      {:error, %HTTPoison.Error{reason: :checkout_timeout}} ->
        Logger.error(
          "Request timed out. Timeout values: [connect: #{state.connect_timeout_milliseconds}ms, read: #{state.read_timeout_milliseconds}ms]"
        )

      _error ->
        :ok
    end
  end

  @impl GenServer
  # Work around leaking messages from hackney (see https://github.com/benoitc/hackney/issues/464#issuecomment-495731612)
  # Seems to be an issue in OTP 21 and later.
  def handle_info({:ssl_closed, _msg}, state), do: {:noreply, state}
end
