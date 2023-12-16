defmodule ConfigCat.ConfigCatLogger do
  @moduledoc false

  @spec debug(String.t()) :: Macro.t()
  @spec debug(String.t(), keyword()) :: Macro.t()
  defmacro debug(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.debug(fn -> module.formatted_message(message, metadata) end)
    end
  end

  @spec error(String.t()) :: Macro.t()
  @spec error(String.t(), keyword()) :: Macro.t()
  defmacro error(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.error(fn -> module.formatted_message(message, metadata) end)

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

      Logger.info(fn -> module.formatted_message(message, metadata) end)
    end
  end

  @spec warning(String.t()) :: Macro.t()
  @spec warning(String.t(), keyword()) :: Macro.t()
  defmacro warning(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      Logger.warning(fn -> module.formatted_message(message, metadata) end)
    end
  end

  @spec warn_offline :: String.t()
  def warn_offline do
    message = "Client is in offline mode; it cannot initiate HTTP calls."
    warning(message, event_id: 3200)
    message
  end

  @doc false
  @spec formatted_message(String.t(), keyword()) :: {String.t(), keyword()}
  def formatted_message(message, metadata) do
    logger_metadata = Logger.metadata()
    event_id = metadata[:event_id] || logger_metadata[:event_id] || 0
    instance_id = metadata[:instance_id] || logger_metadata[:instance_id]

    prefix = if instance_id, do: "[#{instance_id}] ", else: ""

    {prefix <> "[#{event_id}] " <> message, metadata}
  end
end
