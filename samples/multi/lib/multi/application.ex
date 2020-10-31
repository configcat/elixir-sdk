defmodule Multi.Application do
  @moduledoc false

  use Application

  require Logger

  @sdk_key_1 "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A"
  @sdk_key_2 "PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ"

  def start(_type, _args) do
    Logger.configure(level: :info)

    children = [
      Supervisor.child_spec({ConfigCat, [sdk_key: @sdk_key_1, name: :first]}, id: :config_cat_1),
      Supervisor.child_spec({ConfigCat, [sdk_key: @sdk_key_2, name: :second]}, id: :config_cat_2),
      Multi
    ]

    opts = [strategy: :one_for_one, name: Multi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
