defmodule ConfigCat.Hooks.State do
  @moduledoc false
  use TypedStruct

  require Logger

  @type callback :: fun()
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
          error = "Exception occurred during #{hook} callback: #{inspect(e)}"

          unless hook == :on_error do
            Logger.error(error)
            invoke_hook(state, :on_error, [error])
          end
      end
    end)

    :ok
  end

  defp invoke_callback(callback, args) when is_function(callback) do
    apply(callback, args)
  end

  defp invoke_callback({module, function, arity}, args) when length(args) == arity do
    apply(module, function, args)
  end

  defp invoke_callback({module, function, arity}, args) do
    raise ArgumentError,
          "Callback #{module}.#{function}/#{arity} has incorrect arity. Expected #{length(args)} but was #{arity}."
  end
end
