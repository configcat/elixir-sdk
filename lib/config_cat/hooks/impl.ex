defmodule ConfigCat.Hooks.Impl do
  @moduledoc false
  use TypedStruct

  require ConfigCat.ConfigCatLogger, as: ConfigCatLogger
  require Logger

  @type callback :: fun() | tuple()
  @type hook :: :on_client_ready | :on_config_changed | :on_error | :on_flag_evaluated

  typedstruct do
    field :on_client_ready, [callback()], default: []
    field :on_config_changed, [callback()], default: []
    field :on_error, [callback()], default: []
    field :on_flag_evaluated, [callback()], default: []
  end

  @spec new(keyword()) :: t()
  def new(options \\ []) do
    hooks = Enum.map(options, fn {key, value} -> {key, List.wrap(value)} end)
    struct!(__MODULE__, hooks)
  end

  @spec add_hook(t(), hook(), callback()) :: t()
  def add_hook(%__MODULE__{} = state, hook, callback) do
    Map.update!(state, hook, &[callback | &1])
  end

  @spec invoke_hook(t(), hook(), [any()]) :: :ok
  def invoke_hook(%__MODULE__{} = state, hook, args) do
    state
    |> Map.fetch!(hook)
    |> Enum.each(fn callback ->
      try do
        invoke_callback(callback, args)
      rescue
        e ->
          message = "Exception occurred during #{hook} callback: #{inspect(e)}"

          if hook == :on_error do
            # Call Logger instead of ConfigCatLogger to avoid recursively invoking a
            # bad on_error hook.
            Logger.error(message)
          else
            ConfigCatLogger.error(message)
          end
      end
    end)

    :ok
  end

  defp invoke_callback(callback, args) when is_function(callback) do
    apply(callback, args)
  end

  defp invoke_callback({module, function, extra_args}, args) do
    apply(module, function, args ++ extra_args)
  end
end
