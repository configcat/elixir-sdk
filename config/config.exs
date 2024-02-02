import Config

if config_env() == :dev do
  config :mix_test_interactive, clear: true
end

if config_env() == :test do
  config :logger, level: :warning

  if Version.compare(System.version(), "1.15.0") == :lt do
    config :logger, :console,
      colors: [enabled: false],
      format: "$level $message\n"
  else
    config :logger, :default_formatter,
      colors: [enabled: false],
      format: "$level $message\n"
  end
end
