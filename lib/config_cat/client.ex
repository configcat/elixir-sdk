defmodule ConfigCat.Client do
  require ConfigCat.Constants
  require Logger

  use GenServer

  alias ConfigCat.{FetchPolicy, Rollout, Constants}
  alias HTTPoison.Response

  def start_link(options) do
    with {name, options} <- Keyword.pop!(options, :name),
         {sdk_key, options} <- Keyword.pop!(options, :sdk_key),
         {initial_config, options} <- Keyword.pop(options, :initial_config) do
      initial_state = %{
        config: initial_config,
        etag: nil,
        last_update: nil,
        options: Keyword.merge(default_options(), options),
        sdk_key: sdk_key
      }

      GenServer.start_link(__MODULE__, initial_state, name: name)
    end
  end

  defp default_options, do: [api: ConfigCat.API, fetch_policy: FetchPolicy.auto()]

  def get_all_keys(client) do
    GenServer.call(client, :get_all_keys)
  end

  def get_value(client, key, default_value, user) do
    GenServer.call(client, {:get_value, key, default_value, user})
  end

  def get_variation_id(client, key, default_variation_id, user) do
    GenServer.call(client, {:get_variation_id, key, default_variation_id, user})
  end

  def force_refresh(client) do
    GenServer.call(client, :force_refresh)
  end

  @impl GenServer
  def init(state) do
    {:ok, state, {:continue, :maybe_init_fetch}}
  end

  @impl GenServer
  def handle_call(:get_all_keys, _from, state) do
    with {:ok, new_state} <- maybe_refresh(state) do
      feature_flags = Map.get(new_state.config || %{}, Constants.feature_flags(), %{})
      keys = Map.keys(feature_flags)
      {:reply, keys, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_value, key, default_value, user}, _from, state) do
    with {:ok, new_state} <- maybe_refresh(state),
         {value, _variation} <- Rollout.evaluate(key, user, default_value, nil, new_state.config) do
      {:reply, value, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:get_variation_id, key, default_variation_id, user}, _from, state) do
    with {:ok, new_state} <- maybe_refresh(state),
         {_value, variation} <-
           Rollout.evaluate(key, user, nil, default_variation_id, new_state.config) do
      {:reply, variation, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:force_refresh, _from, state) do
    with {:ok, new_state} <- refresh(state) do
      {:reply, :ok, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  defp schedule_initial_fetch?(%{options: options}) do
    options
    |> Keyword.get(:fetch_policy)
    |> FetchPolicy.schedule_initial_fetch?()
  end

  defp maybe_refresh(%{options: options} = state) do
    options
    |> Keyword.get(:fetch_policy)
    |> maybe_refresh(state)
  end

  defp maybe_refresh(fetch_policy, %{last_update: last_update} = state) do
    if FetchPolicy.needs_fetch?(fetch_policy, last_update) do
      refresh(state)
    else
      {:ok, state}
    end
  end

  defp refresh(%{options: options, etag: etag} = state) do
    Logger.info("Fetching configuration from ConfigCat")

    with api <- Keyword.get(options, :api),
         fetch_policy <- Keyword.get(options, :fetch_policy),
         {:ok, response} <-
           api.get(url(state), headers(fetch_policy, etag), http_options(options)) do
      response
      |> log_response()
      |> handle_response(state)
    else
      error ->
        log_error(error)
    end
  end

  defp http_options(options) do
    opts = []
    http_proxy = Keyword.get(options, :http_proxy)

    if http_proxy != nil do
      opts ++ [proxy: http_proxy]
    else
      opts
    end
  end

  defp handle_response(%Response{status_code: code, body: config, headers: headers}, state)
       when code >= 200 and code < 300 do
    with etag <- extract_etag(headers) do
      {:ok, %{state | config: config, etag: etag, last_update: now()}}
    end
  end

  defp handle_response(%Response{status_code: 304}, state) do
    {:ok, %{state | last_update: now()}}
  end

  defp handle_response(response, _state) do
    {:error, response}
  end

  defp headers(fetch_policy, etag), do: base_headers(fetch_policy) ++ cache_headers(etag)

  defp base_headers(fetch_policy) do
    version = Application.spec(:config_cat, :vsn) |> to_string()
    mode = FetchPolicy.mode(fetch_policy)
    user_agent = "ConfigCat-Elixir/#{mode}-#{version}"

    [
      {"User-Agent", user_agent},
      {"X-ConfigCat-UserAgent", user_agent}
    ]
  end

  defp cache_headers(nil), do: []
  defp cache_headers(etag), do: [{"If-None-Match", etag}]

  defp extract_etag(headers) do
    headers |> Enum.into(%{}) |> Map.get("ETag")
  end

  defp url(%{options: options, sdk_key: sdk_key}) do
    base_url = Keyword.get(options, :base_url, Constants.base_url())

    base_url
    |> URI.parse()
    |> URI.merge("#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}")
    |> URI.to_string()
  end

  defp now, do: DateTime.utc_now()

  defp log_response(%Response{headers: headers, status_code: status_code} = response) do
    Logger.info(
      "ConfigCat configuration json fetch response code: #{status_code} Cached: #{
        extract_etag(headers)
      }"
    )

    response
  end

  defp log_error(error) do
    Logger.warn("Failed to fetch configuration from ConfigCat: #{inspect(error)}")
    error
  end

  defp schedule_and_refresh(%{options: options} = state) do
    options
    |> Keyword.get(:fetch_policy)
    |> FetchPolicy.schedule_next_fetch(self())

    case refresh(state) do
      {:ok, new_state} -> new_state
      _error -> state
    end
  end

  @impl GenServer
  # Work around leaking messages from hackney (see https://github.com/benoitc/hackney/issues/464#issuecomment-495731612)
  # Seems to be an issue in OTP 21 and later.
  def handle_info({:ssl_closed, _msg}, state), do: {:noreply, state}

  @impl GenServer
  def handle_info(:refresh, state) do
    {:noreply, schedule_and_refresh(state)}
  end

  @impl GenServer
  def handle_continue(:maybe_init_fetch, state) do
    if schedule_initial_fetch?(state) do
      {:noreply, schedule_and_refresh(state)}
    else
      {:noreply, state}
    end
  end
end
