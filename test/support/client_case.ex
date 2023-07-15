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

  @spec start_client([Client.option()]) :: {:ok, GenServer.server()}
  def start_client(opts \\ []) do
    instance_id = UUID.uuid4() |> String.to_atom()

    options =
      [
        cache_policy: MockCachePolicy,
        flag_overrides: NullDataSource.new(),
        instance_id: instance_id
      ]
      |> Keyword.merge(opts)

    {:ok, pid} = start_supervised({Client, options})

    Mox.allow(MockCachePolicy, self(), pid)

    {:ok, instance_id}
  end

  @spec stub_cached_config({:ok, Config.t()} | {:error, :not_found}) :: :ok
  def stub_cached_config(response) do
    MockCachePolicy
    |> Mox.stub(:get, fn _id -> response end)

    :ok
  end
end
