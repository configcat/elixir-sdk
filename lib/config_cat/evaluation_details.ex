defmodule ConfigCat.EvaluationDetails do
  @moduledoc """
  Captures the results of evaluating a feature flag.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.User

  @typedoc """
  The results of evaluating a feature flag.

  Fields:
  - `:default_value?`: Indicates whether the default value passed to the setting
    evaluation functions like `ConfigCat.get_value/3`,
    `ConfigCat.get_value_details/3`, etc. is used as the result of the
    evaluation.
  - `:error`: Error message in case evaluation failed.
  - `:fetch_time`: Time of the last successful config download.
  - `:key`: The key of the feature flag or setting.
  - `:matched_targeting_rule`: The targeting rule (if any) that matched during
    the evaluation and was used to return the evaluated value.
  - `:matched_percentage_option`: The percentage option (if any) that was used
    to select the evaluated value.
  - `:user`: The `ConfigCat.User` struct used for the evaluation (if available).
  - `:value`: Evaluated value of the feature flag or setting.
  - `:variation_id`: Variation ID of the feature flag or setting (if available).
  """
  typedstruct do
    field :default_value?, boolean(), default: false
    field :error, String.t()
    field :fetch_time, DateTime.t()
    field :key, Config.key(), enforce: true
    field :matched_targeting_rule, map()
    field :matched_percentage_option, map()
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
