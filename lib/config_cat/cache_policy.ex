defmodule ConfigCat.CachePolicy do
  alias ConfigCat.{ConfigCache, ConfigFetcher}
  alias __MODULE__.{Auto, Lazy, Manual}

  @type option ::
          {:cache, module()}
          | {:cache_key, ConfigCache.key()}
          | {:cache_policy, t()}
          | {:fetcher_id, ConfigFetcher.id()}
          | {:name, policy_id()}
  @type options :: [option]
  @type policy_id :: atom()
  @type refresh_result :: :ok | ConfigFetcher.fetch_error()
  @type t :: Auto.t() | Lazy.t() | Manual.t()

  @callback get(policy_id()) :: {:ok, map()} | {:error, :not_found}
  @callback force_refresh(policy_id()) :: refresh_result()

  @spec auto(Auto.options()) :: Auto.t()
  def auto(options \\ []) do
    Auto.new(options)
  end

  @spec lazy(Lazy.options()) :: Lazy.t()
  def lazy(options) do
    Lazy.new(options)
  end

  @spec manual :: Manual.t()
  def manual do
    Manual.new()
  end

  @spec policy_name(t()) :: atom()
  def policy_name(%policy{}), do: policy

  @spec policy_name(options()) :: atom()
  def policy_name(options) when is_list(options) do
    options
    |> Keyword.fetch!(:cache_policy)
    |> policy_name()
  end

  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(options) do
    policy_name(options).child_spec(options)
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    policy_name(options).start_link(options)
  end
end
