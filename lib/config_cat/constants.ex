defmodule ConfigCat.Constants do
  defmacro base_url, do: "https://cdn.configcat.com"
  defmacro base_path, do: "configuration-files"
  defmacro config_filename, do: "config_v5.json"

  defmacro feature_flags, do: "f"
  defmacro comparator, do: "t"
  defmacro comparison_attribute, do: "a"
  defmacro comparison_value, do: "c"
  defmacro rollout_rules, do: "r"
  defmacro percentage_rules, do: "p"
  defmacro percentage, do: "p"
  defmacro value, do: "v"
  defmacro variation_id, do: "i"
end
