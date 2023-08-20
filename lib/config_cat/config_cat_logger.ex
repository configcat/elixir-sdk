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

      instance_id = Logger.metadata() |> Keyword.get(:instance_id)

      message
      |> module.format_message(instance_id)
      |> Logger.error(metadata)

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

      instance_id = Logger.metadata() |> Keyword.get(:instance_id)

      message
      |> module.format_message(instance_id)
      |> Logger.info(metadata)
    end
  end

  @spec warn(String.t()) :: Macro.t()
  @spec warn(String.t(), keyword()) :: Macro.t()
  defmacro warn(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, module: __MODULE__] do
      require Logger

      instance_id = Logger.metadata() |> Keyword.get(:instance_id)

      message
      |> module.format_message(instance_id)
      |> Logger.warn(metadata)
    end
  end

  @doc false
  @spec format_message(String.t(), ConfigCat.instance_id() | nil) :: String.t()
  def format_message(message, nil), do: message
  def format_message(message, instance_id), do: "[" <> to_string(instance_id) <> "] " <> message
end
