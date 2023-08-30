defmodule Multi.Application do
  @moduledoc false

  use Application

  require Logger

  @sdk_key_1 "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A"
  @sdk_key_2 "PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ"

  @impl Application
  def start(_type, _args) do
    # Debug level logging helps to inspect the feature flag evaluation process.
    # Use the :warning level to avoid too detailed logging in your application.
    Logger.configure(level: :debug)

    children = [
      {Multi.First, sdk_key: @sdk_key_1},
      {Multi.Second, sdk_key: @sdk_key_2},
      Multi
    ]

    opts = [strategy: :one_for_one, name: Multi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
