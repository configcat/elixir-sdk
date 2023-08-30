defmodule Multi.Application do
  @moduledoc false

  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    # Debug level logging helps to inspect the feature flag evaluation process.
    # Use the :warning level to avoid too detailed logging in your application.
    Logger.configure(level: :debug)

    children = [
      Multi.First,
      Multi.Second,
      Multi
    ]

    opts = [strategy: :one_for_one, name: Multi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
