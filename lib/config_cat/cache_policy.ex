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

  def policy_name(%policy{}), do: policy

  def policy_name(options) when is_list(options) do
    options
    |> Keyword.fetch!(:cache_policy)
    |> policy_name()
  end

  def child_spec(options) do
    policy_name(options).child_spec(options)
  end

  def start_link(options) do
    policy_name(options).start_link(options)
  end
end
