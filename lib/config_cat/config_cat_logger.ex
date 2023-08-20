defmodule ConfigCat.ConfigCatLogger do
  @moduledoc false

  @spec debug(String.t()) :: Macro.t()
  @spec debug(String.t(), keyword()) :: Macro.t()
  defmacro debug(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata] do
      require Logger

      Logger.debug(message, metadata)
    end
  end

  @spec error(String.t()) :: Macro.t()
  @spec error(String.t(), keyword()) :: Macro.t()
  defmacro error(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata] do
      require Logger

      instance_id = Logger.metadata() |> Keyword.get(:instance_id)
      Logger.error(message, metadata)

      if instance_id do
        ConfigCat.Hooks.invoke_on_error(instance_id, message)
      end
    end
  end

  @spec info(String.t()) :: Macro.t()
  @spec info(String.t(), keyword()) :: Macro.t()
  defmacro info(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata] do
      require Logger

      Logger.info(message, metadata)
    end
  end

  @spec warn(String.t()) :: Macro.t()
  @spec warn(String.t(), keyword()) :: Macro.t()
  defmacro warn(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata] do
      require Logger

      Logger.warn(message, metadata)
    end
  end
end
