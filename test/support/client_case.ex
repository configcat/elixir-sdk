defmodule ConfigCat.ClientCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias ConfigCat.Client
  alias ConfigCat.MockCachePolicy
  alias ConfigCat.NullDataSource

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  @cache_policy_id :cache_policy_id

  @spec start_client([Client.option()]) :: {:ok, GenServer.server()}
  def start_client(opts \\ []) do
    base_name = UUID.uuid4() |> String.to_atom()
    name = ConfigCat.Supervisor.client_name(base_name)

    options =
      [
        cache_policy: MockCachePolicy,
        cache_policy_id: @cache_policy_id,
        flag_overrides: NullDataSource.new(),
        name: name
      ]
      |> Keyword.merge(opts)

    {:ok, pid} = start_supervised({Client, options})

    Mox.allow(MockCachePolicy, self(), pid)

    {:ok, base_name}
  end

  @spec stub_cached_config({:ok, Config.t()} | {:error, :not_found}) :: :ok
  def stub_cached_config(response) do
    MockCachePolicy
    |> Mox.stub(:get, fn @cache_policy_id -> response end)

    :ok
  end
end
