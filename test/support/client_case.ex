defmodule ConfigCat.ClientCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias ConfigCat.Client
  alias ConfigCat.FetchTime
  alias ConfigCat.Hooks
  alias ConfigCat.MockCachePolicy
  alias ConfigCat.NullDataSource

  using opts do
    quote do
      use ConfigCat.Case, unquote(opts)

      import unquote(__MODULE__)
    end
  end

  @spec start_client([Client.option()]) :: {:ok, GenServer.server()}
  def start_client(opts \\ []) do
    instance_id = String.to_atom(UUID.uuid4())

    start_supervised!({Hooks, instance_id: instance_id})

    options =
      Keyword.merge([cache_policy: MockCachePolicy, flag_overrides: NullDataSource.new(), instance_id: instance_id], opts)

    {:ok, pid} = start_supervised({Client, options})

    Mox.allow(MockCachePolicy, self(), pid)

    {:ok, instance_id}
  end

  @spec stub_cached_config(
          {:ok, Config.t(), FetchTime.t()}
          | {:error, :not_found}
        ) ::
          :ok
  def stub_cached_config(response) do
    Mox.stub(MockCachePolicy, :get, fn _id -> response end)
    :ok
  end
end
