defmodule Simple.Application do
  @moduledoc false

  use Application

  require Logger

  @sdk_key "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A"

  def start(_type, _args) do

    # Info level logging helps to inspect the feature flag evaluation process.
    # Use the :warning level to avoid too detailed logging in your application.
    Logger.configure(level: :info)

    children = [
      {ConfigCat, [sdk_key: @sdk_key]},
      Simple
    ]

    opts = [strategy: :one_for_one, name: Simple.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
