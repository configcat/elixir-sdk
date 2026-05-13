defmodule ConfigCat.HTTPClient.Finch do
  @moduledoc """
  `ConfigCat.HTTPClient` adapter built on
  [Finch](https://hex.pm/packages/finch).

  Finch is declared as an optional dependency, so it is only pulled in when
  the application elects to use it.

  ## Usage

  Start a Finch pool in your application supervision tree, configure the
  pool name for the adapter, and select it as the SDK's HTTP client:

      # config/config.exs
      config :configcat, ConfigCat.HTTPClient.Finch, name: MyApp.Finch

      # application.ex
      children = [
        {Finch, name: MyApp.Finch},
        {ConfigCat, sdk_key: "...", http_client: ConfigCat.HTTPClient.Finch}
      ]

  ## Option translation

  The SDK passes HTTPoison-shaped options to the adapter; this module
  translates the relevant ones to Finch's request options:

  - `:timeout`       → Finch `:pool_timeout`
  - `:recv_timeout`  → Finch `:receive_timeout`
  - `:proxy`         → ignored (configure your Finch pool instead)

  Errors classified as transient: `:timeout`, `:closed`, `:econnrefused`,
  `:nxdomain`.
  """

  @behaviour ConfigCat.HTTPClient

  @compile {:no_warn_undefined, [Finch]}

  @transient_reasons ~w(timeout closed econnrefused nxdomain)a

  @impl ConfigCat.HTTPClient
  def get(url, headers, opts) do
    ensure_finch!()

    headers = [{"Accept", "application/json"} | headers]
    request = Finch.build(:get, url, headers)
    request_opts = build_request_opts(opts)

    case Finch.request(request, finch_name(), request_opts) do
      {:ok, %{status: status, body: body, headers: response_headers}} ->
        {:ok, %{status: status, body: body, headers: response_headers}}

      {:error, %{reason: reason}} ->
        {:error, %{reason: reason, transient?: reason in @transient_reasons}}

      {:error, reason} ->
        {:error, %{reason: reason, transient?: false}}
    end
  end

  defp finch_name do
    Application.get_env(:configcat, __MODULE__, [])[:name] ||
      raise ArgumentError, """
      #{inspect(__MODULE__)} requires the name of a Finch pool. Configure it:

          config :configcat, #{inspect(__MODULE__)}, name: MyApp.Finch
      """
  end

  defp build_request_opts(opts) do
    Enum.flat_map(opts, fn
      {:timeout, value} -> [pool_timeout: value]
      {:recv_timeout, value} -> [receive_timeout: value]
      _ -> []
    end)
  end

  defp ensure_finch! do
    if Code.ensure_loaded?(Finch) do
      :ok
    else
      raise """
      #{inspect(__MODULE__)} requires the optional :finch dependency.

      Add it to your deps:

          {:finch, "~> 0.18"}
      """
    end
  end
end
