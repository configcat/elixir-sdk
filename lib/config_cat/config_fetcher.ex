defmodule ConfigCat.ConfigFetcher do
  @moduledoc false

  alias ConfigCat.ConfigEntry
  alias HTTPoison.Response

  defmodule FetchError do
    @moduledoc false
    @enforce_keys [:reason, :transient?]
    defexception [:reason, :transient?]

    @type option :: {:reason, any()} | {:transient?, boolean()}
    @type t :: %__MODULE__{
            reason: any(),
            transient?: boolean()
          }

    @impl Exception
    def exception(options) do
      struct!(__MODULE__, options)
    end

    @impl Exception
    def message(%__MODULE__{} = error) do
      "Unexpected error occurred while trying to fetch config JSON: #{inspect(error.reason)}"
    end
  end

  @type result :: {:ok, ConfigEntry.t()} | {:ok, :unchanged} | {:error, FetchError.t()}

  @callback fetch(ConfigCat.instance_id(), String.t()) :: result()
end

defmodule ConfigCat.CacheControlConfigFetcher do
  @moduledoc false

  use GenServer

  alias ConfigCat.Config
  alias ConfigCat.ConfigEntry
  alias ConfigCat.ConfigFetcher
  alias ConfigCat.ConfigFetcher.FetchError
  alias HTTPoison.Response

  require ConfigCat.Constants, as: Constants
  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger
  require ConfigCat.RedirectMode, as: RedirectMode

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct enforce: true do
      field :api, module(), default: ConfigCat.API
      field :base_url, String.t()
      field :callers, [GenServer.from()], default: []
      field :connect_timeout_milliseconds, non_neg_integer(), default: 8_000
      field :custom_endpoint?, boolean()
      field :data_governance, ConfigCat.data_governance(), default: :global
      field :http_proxy, String.t(), enforce: false
      field :instance_id, ConfigCat.instance_id()
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

    @spec add_caller(t(), GenServer.from()) :: t()
    def add_caller(%__MODULE__{} = state, caller) do
      %{state | callers: [caller | state.callers]}
    end

    @spec clear_callers(t()) :: t()
    def clear_callers(%__MODULE__{} = state) do
      %{state | callers: []}
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
    instance_id = Keyword.fetch!(options, :instance_id)

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
    Logger.metadata(instance_id: state.instance_id)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:fetch, etag}, from, %State{callers: []} = state) do
    pid = self()

    Task.start_link(fn ->
      Logger.metadata(instance_id: state.instance_id)
      result = do_fetch(state, etag)
      send(pid, {:fetch_complete, result})
    end)

    new_state = State.add_caller(state, from)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:fetch, _etag}, from, %State{} = state) do
    new_state = State.add_caller(state, from)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:fetch_complete, result}, %State{} = state) do
    {status, payload, new_state} = result

    for caller <- state.callers do
      GenServer.reply(caller, {status, payload})
    end

    {:noreply, State.clear_callers(new_state)}
  end

  @impl GenServer
  # Work around leaking messages from hackney (see https://github.com/benoitc/hackney/issues/464#issuecomment-495731612)
  # Seems to be an issue in OTP 21 and later.
  def handle_info({:ssl_closed, _msg}, %State{} = state), do: {:noreply, state}

  defp do_fetch(%State{} = state, etag) do
    ConfigCatLogger.debug("Fetching configuration from ConfigCat")

    case state.api.get(url(state), headers(state, etag), http_options(state)) do
      {:ok, response} ->
        handle_response(response, state, etag)

      error ->
        {:error, handle_error(error, state), state}
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
    ConfigCatLogger.debug(
      "ConfigCat configuration json fetch response code: #{code} Cached: #{extract_etag(headers)}"
    )

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
            ConfigCatLogger.error(
              "Redirection loop encountered while trying to fetch config JSON. Please contact us at https://configcat.com/support/",
              event_id: 1104
            )

            # redirects needs reset as customers might change their configs at any time.
            %{state | redirects: %{}}

          true ->
            state
        end

      if redirect_mode == RedirectMode.should_redirect() do
        ConfigCatLogger.warn(
          "The `dataGovernance` parameter specified at the client initialization is not in sync with the preferences on the ConfigCat Dashboard. " <>
            "Read more: https://configcat.com/docs/advanced/data-governance/",
          event_id: 3002
        )
      end

      entry = ConfigEntry.new(config, new_etag, raw_config)

      {:ok, entry, new_state}
    end
  end

  defp handle_response(%Response{status_code: 304}, %State{} = state, _etag) do
    {:ok, :unchanged, state}
  end

  defp handle_response(%Response{status_code: status} = response, %State{} = state, _etag)
       when status in [403, 404] do
    ConfigCatLogger.error(
      "Your SDK Key seems to be wrong. You can find the valid SDKKey at https://app.configcat.com/sdkkey. Received unexpected response: #{inspect(response)}",
      event_id: 1100
    )

    error = FetchError.exception(reason: response, transient?: false)

    {:error, error, state}
  end

  defp handle_response(response, %State{} = state, _etag) do
    ConfigCatLogger.error(
      "Unexpected HTTP response was received while trying to fetch config JSON: #{inspect(response)}",
      event_id: 1101
    )

    error = FetchError.exception(reason: response, transient?: true)

    {:error, error, state}
  end

  defp handle_error(
         {:error, %HTTPoison.Error{reason: :checkout_timeout} = error},
         %State{} = state
       ) do
    ConfigCatLogger.error(
      "Request timed out while trying to fetch config JSON. Timeout values: [connect: #{state.connect_timeout_milliseconds}ms, read: #{state.read_timeout_milliseconds}ms]",
      event_id: 1102
    )

    FetchError.exception(reason: error, transient?: true)
  end

  defp handle_error({:error, error}, _state) do
    ConfigCatLogger.error(
      "Unexpected error occurred while trying to fetch config JSON: #{inspect(error)}",
      event_id: 1103
    )

    FetchError.exception(reason: error, transient?: true)
  end

  defp extract_etag(headers) do
    case List.keyfind(headers, "ETag", 0) do
      nil -> nil
      {_key, value} -> value
    end
  end
end
