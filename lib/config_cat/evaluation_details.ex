defmodule ConfigCat.EvaluationDetails do
  @moduledoc """
  Captures the results of evaluating a feature flag.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.User

  typedstruct do
    field :default_value?, boolean(), default: false
    field :error, String.t()
    field :fetch_time, DateTime.t()
    field :key, Config.key(), enforce: true
    field :matched_evaluation_rule, map()
    field :matched_evaluation_percentage_rule, map()
    field :user, User.t()
    field :value, Config.value(), enforce: true
    field :variation_id, Config.variation_id()
  end

  @doc false
  @spec new(keyword()) :: t()
  def new(options) do
    struct!(__MODULE__, options)
  end
end
