[
  # The following four ignore rules are due to an upstream type problem in
  # HTTPoison 3.0. Once https://github.com/edgurgel/httpoison/pull/511 has been
  # merged and released, we should be able to delete these rules.
  {"deps/httpoison/lib/httpoison/base.ex", "Type mismatch with behaviour callback to stream_next/1."},
  {"deps/httpoison/lib/httpoison/base.ex", "Type mismatch for @callback stream_next."},
  {"deps/httpoison/lib/httpoison/base.ex",
   "The pattern variable _3 can never match the type, because it is covered by previous clauses."},
  {"lib/config_cat/api.ex", "Invalid type specification for function stream_next."}
]
