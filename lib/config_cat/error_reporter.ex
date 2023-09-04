defmodule ConfigCat.ErrorReporter do
  @moduledoc false

  @type opt :: {:instance_id, ConfigCat.instance_id()} | {:skip_hook?, boolean()}

  @spec call(String.t()) :: Macro.t()
  @spec call(String.t(), [opt]) :: Macro.t()
  defmacro call(message, opts \\ []) do
    instance_id = Keyword.fetch!(opts, :instance_id)
    skip_hook? = Keyword.get(opts, :skip_hook?, false)

    quote bind_quoted: [instance_id: instance_id, message: message, skip_hook?: skip_hook?] do
      require Logger

      Logger.error(message)

      unless skip_hook? do
        ConfigCat.Hooks.invoke_on_error(instance_id, message)
      end
    end
  end
end
