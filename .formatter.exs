# Used by "mix format"
[
  import_deps: [:typed_struct],
  inputs: ["{mix,.credo,.dialyzer_ignore,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Styler]
]
