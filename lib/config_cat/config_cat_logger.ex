defmodule ConfigCat.ConfigCatLogger do
  @moduledoc false

  @spec debug(String.t()) :: Macro.t()
  @spec debug(String.t(), keyword()) :: Macro.t()
  defmacro debug(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.debug(message, metadata)
    end
  end

  @spec error(String.t()) :: Macro.t()
  @spec error(String.t(), keyword()) :: Macro.t()
  defmacro error(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.error(fn -> module.formatted_message(message) end)

      instance_id = Logger.metadata() |> Keyword.get(:instance_id)

      if instance_id do
        ConfigCat.Hooks.invoke_on_error(instance_id, message)
      end
    end
  end

  @spec info(String.t()) :: Macro.t()
  @spec info(String.t(), keyword()) :: Macro.t()
  defmacro info(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.info(fn -> module.formatted_message(message) end)
    end
  end

  @spec warn(String.t()) :: Macro.t()
  @spec warn(String.t(), keyword()) :: Macro.t()
  defmacro warn(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.warn(fn -> module.formatted_message(message) end)
    end
  end

  @doc false
  @spec formatted_message(String.t()) :: String.t()
  def formatted_message(message) do
    case Logger.metadata() |> Keyword.get(:instance_id) do
      nil -> message
      instance_id -> "[" <> to_string(instance_id) <> "] " <> message
    end
  end
end
