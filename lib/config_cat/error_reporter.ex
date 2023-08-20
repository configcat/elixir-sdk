defmodule ConfigCat.ErrorReporter do
  @moduledoc false

  @spec call(String.t()) :: Macro.t()
  defmacro call(message) do
    quote bind_quoted: [message: message] do
      require Logger

      instance_id = Logger.metadata() |> Keyword.get(:instance_id)
      Logger.error(message)

      if instance_id do
        ConfigCat.Hooks.invoke_on_error(instance_id, message)
      end
    end
  end
end
