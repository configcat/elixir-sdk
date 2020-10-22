defmodule ConfigCat.Constants do

  @feature_flags "f"
  @comparator "t"
  @comparison_attribute "a"
  @comparison_value "c"
  @rollout_rules "r"
  @percentage_rules "p"
  @percentage "p"
  @value "v"
  @variation_id "i"

  defmacro feature_flags, do: @feature_flags
  defmacro comparator, do: @comparator
  defmacro comparison_attribute, do: @comparison_attribute
  defmacro comparison_value, do: @comparison_value
  defmacro rollout_rules, do: @rollout_rules
  defmacro percentage_rules, do: @percentage_rules
  defmacro percentage, do: @percentage
  defmacro value, do: @value
  defmacro variation_id, do: @variation_id
end
