defmodule ConfigCat.Config.TargetingRule do
  @moduledoc false
  alias ConfigCat.Config

  @type opt ::
          {:comparator, Config.comparator()}
          | {:comparison_attribute, String.t()}
          | {:comparison_value, Config.value()}
          | {:value, Config.value()}
          | {:variation_id, Config.variation_id()}
  @type t :: %{String.t() => term()}

  @comparator "t"
  @comparison_attribute "a"
  @comparison_value "c"
  @value "v"
  @variation_id "i"

  @spec new([opt]) :: t()
  def new(opts \\ []) do
    %{
      @comparator => opts[:comparator],
      @comparison_attribute => opts[:comparison_attribute],
      @comparison_value => opts[:comparison_value],
      @value => opts[:value],
      @variation_id => opts[:variation_id]
    }
  end

  @spec comparator(t()) :: Config.comparator() | nil
  def comparator(rule) do
    Map.get(rule, @comparator)
  end

  @spec comparison_attribute(t()) :: String.t() | nil
  def comparison_attribute(rule) do
    Map.get(rule, @comparison_attribute)
  end

  @spec comparison_value(t()) :: Config.value() | nil
  def comparison_value(rule) do
    Map.get(rule, @comparison_value)
  end

  @spec value(t()) :: Config.value()
  def value(rule) do
    Map.get(rule, @value)
  end

  @spec variation_id(t()) :: Config.variation_id() | nil
  def variation_id(rule) do
    Map.get(rule, @variation_id)
  end

  @spec variation_value(t(), Config.variation_id()) :: Config.value() | nil
  def variation_value(rule, variation_id) do
    if variation_id(rule) == variation_id do
      value(rule)
    end
  end
end
