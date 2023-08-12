defmodule ConfigCat.ConfigFetcher do
  @moduledoc false

  alias ConfigCat.ConfigEntry
  alias HTTPoison.Error
  alias HTTPoison.Response

  @type fetch_error :: {:error, Error.t() | Response.t()}
  @type result :: {:ok, ConfigEntry.t()} | {:ok, :unchanged} | fetch_error()

  @callback fetch(ConfigCat.instance_id(), String.t()) :: result()
end

defmodule ConfigCat.CacheControlConfigFetcher do
  @moduledoc false

  use GenServer

  alias ConfigCat.Config
  alias ConfigCat.ConfigEntry
  alias ConfigCat.ConfigFetcher
  alias HTTPoison.Response

  require ConfigCat.Constants, as: Constants
  require ConfigCat.RedirectMode, as: RedirectMode
  require Logger

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :api, module(), default: ConfigCat.API
      field :base_url, String.t()
      field :connect_timeout_milliseconds, non_neg_integer(), default: 8_000
      field :custom_endpoint?, boolean()
      field :data_governance, ConfigCat.data_governance(), default: :global
      field :http_proxy, String.t(), enforce: false
      field :mode, String.t()
      field :read_timeout_milliseconds, non_neg_integer, default: 5_000
      field :redirects, map(), default: %{}
      field :sdk_key, String.t()
    end

    @spec new(Keyword.t()) :: t()
    def new(options) do
      options = choose_base_url(options)

      struct!(__MODULE__, options)
    end

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
  end

  @type option ::
          {:base_url, String.t()}
          | {:connect_timeout_milliseconds, non_neg_integer()}
          | {:data_governance, ConfigCat.data_governance()}
          | {:http_proxy, String.t()}
          | {:instance_id, ConfigCat.instance_id()}
          | {:mode, String.t()}
          | {:read_timeout_milliseconds, non_neg_integer()}
          | {:sdk_key, String.t()}
  @type options :: [option]

  @behaviour ConfigFetcher

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    {instance_id, options} = Keyword.pop!(options, :instance_id)

    GenServer.start_link(__MODULE__, State.new(options), name: via_tuple(instance_id))
  end

  defp via_tuple(instance_id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}}}
  end

  @impl ConfigFetcher
  def fetch(instance_id, etag) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:fetch, etag}, Constants.fetch_timeout())
  end

  @impl GenServer
  def init(%State{} = state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:fetch, etag}, _from, %State{} = state) do
    do_fetch(state, etag)
  end

  defp do_fetch(%State{} = state, etag) do
    Logger.info("Fetching configuration from ConfigCat")

    with api <- state.api,
         {:ok, response} <-
           api.get(url(state), headers(state, etag), http_options(state)) do
      response
      |> log_response()
      |> handle_response(state, etag)
    else
      error ->
        log_error(error, state)
        {:reply, error, state}
    end
  end

  defp url(%State{base_url: base_url, sdk_key: sdk_key}) do
    base_url
    |> URI.parse()
    |> URI.merge("#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}")
    |> URI.to_string()
  end

  defp headers(state, etag) do
    base_headers(state) ++ cache_headers(etag)
  end

  defp base_headers(%State{mode: mode}) do
    version = Application.spec(:configcat, :vsn) |> to_string()
    user_agent = "ConfigCat-Elixir/#{mode}-#{version}"

    [
      {"User-Agent", user_agent},
      {"X-ConfigCat-UserAgent", user_agent}
    ]
  end

  defp cache_headers(etag) do
    if is_nil(etag), do: [], else: [{"If-None-Match", etag}]
  end

  defp http_options(%State{} = state) do
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
  defp handle_response(
         %Response{status_code: code, body: raw_config, headers: headers},
         %State{} = state,
         etag
       )
       when code >= 200 and code < 300 do
    with {:ok, config} <- Jason.decode(raw_config),
         new_etag <- extract_etag(headers),
         %{base_url: new_base_url, custom_endpoint?: custom_endpoint?, redirects: redirects} <-
           state,
         {base_url, redirect_mode} <- Config.preferences(config) do
      followed? = Map.has_key?(redirects, new_base_url)

      new_state =
        cond do
          custom_endpoint? && redirect_mode != RedirectMode.force_redirect() ->
            state

          redirect_mode == RedirectMode.no_redirect() ->
            state

          base_url && !followed? ->
            state = %{
              state
              | base_url: base_url,
                redirects: Map.put(redirects, base_url, 1)
            }

            {_, _, next_state} = do_fetch(state, etag)

            next_state

          followed? ->
            Logger.warn(
              "Redirect loop during config.json fetch. Please contact support@configcat.com."
            )

            # redirects needs reset as customers might change their configs at any time.
            %{state | redirects: %{}}

          true ->
            state
        end

      if redirect_mode == RedirectMode.should_redirect() do
        Logger.warn("""
        Your data_governance parameter at ConfigCat client initialization
        is not in sync with your preferences on the ConfigCat Dashboard:
        https://app.configcat.com/organization/data-governance.
        Only Organization Admins can set this preference.
        """)
      end

      entry = ConfigEntry.new(config, new_etag, raw_config)

      {:reply, {:ok, entry}, new_state}
    end
  end

  defp handle_response(%Response{status_code: 304}, %State{} = state, _etag) do
    {:reply, {:ok, :unchanged}, state}
  end

  defp handle_response(response, %State{} = state, _etag) do
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

  defp log_error(error, %State{} = state) do
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
  def handle_info({:ssl_closed, _msg}, %State{} = state), do: {:noreply, state}
end
