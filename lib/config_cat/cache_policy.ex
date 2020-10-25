defmodule ConfigCat.CachePolicy do
  @type policy_id :: atom()

  @callback get(policy_id()) :: {:ok, map()} | {:error, :not_found}
  @callback force_refresh(policy_id()) :: :ok | {:error, term()}

  alias __MODULE__.{Auto, Lazy, Manual}

  def auto(options \\ []) do
    Auto.new(options)
  end

  def lazy(options) do
    Lazy.new(options)
  end

  def manual do
    Manual.new()
  end

  def child_spec(options) do
    %policy{} = Keyword.fetch!(options, :cache_policy)
    policy.child_spec(options)
  end

  def start_link(options) do
    %policy{} = Keyword.fetch!(options, :cache_policy)
    policy.start_link(options)
  end
end
