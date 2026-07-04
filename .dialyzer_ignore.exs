[
  # The following four ignore rules are due to an upstream type problem in
  # HTTPoison 3.0. Once https://github.com/edgurgel/httpoison/pull/511 has been
  # merged and released, we should be able to delete these rules.
  {"deps/httpoison/lib/httpoison/base.ex", :callback_arg_type_mismatch},
  {"deps/httpoison/lib/httpoison/base.ex", :callback_type_mismatch},
  {"deps/httpoison/lib/httpoison/base.ex", :pattern_match_cov},
  {"lib/config_cat/api.ex", :invalid_contract}
]
