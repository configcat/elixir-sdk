defmodule ConfigCat.Constants do
  @moduledoc false

  defmacro base_url_global, do: "https://cdn-global.configcat.com"
  defmacro base_url_eu_only, do: "https://cdn-eu.configcat.com"

  defmacro base_path, do: "configuration-files"
  defmacro config_filename, do: "config_v6.json"
  defmacro serialization_format_version, do: "v2"

  defmacro fetch_timeout, do: 10_000
end
