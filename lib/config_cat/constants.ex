defmodule ConfigCat.Constants do
  @moduledoc false

  defmacro base_url_global, do: "https://cdn-global.configcat.com"
  defmacro base_url_eu_only, do: "https://cdn-eu.configcat.com"

  defmacro base_path, do: "configuration-files"
  defmacro config_filename, do: "config_v5.json"

  defmacro feature_flags, do: "f"
  defmacro preferences, do: "p"
  defmacro preferences_base_url, do: "u"
  defmacro redirect, do: "r"
  defmacro comparator, do: "t"
  defmacro comparison_attribute, do: "a"
  defmacro comparison_value, do: "c"
  defmacro rollout_rules, do: "r"
  defmacro percentage_rules, do: "p"
  defmacro percentage, do: "p"
  defmacro value, do: "v"
  defmacro variation_id, do: "i"
  defmacro fetch_timeout, do: 10_000
end
