defmodule ConfigCat.Application do
  @moduledoc false

  use Application

  alias ConfigCat.InMemoryCache

  @impl Application
  def start(_type, _args) do
    children = [{Registry, keys: :unique, name: ConfigCat.Registry}, InMemoryCache]

    opts = [strategy: :one_for_one, name: ConfigCat.RegistrySupervisor]
    Supervisor.start_link(children, opts)
  end
end
