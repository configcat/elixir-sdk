defmodule ConfigCat.Hooks do
  @moduledoc """
  Subscribe to events fired by the SDK.

  Hooks are callback functions that are called by the SDK when certain events
  happen. Client applications can register more than one callback for each hook.

  Callbacks are called within the same process that generated the event. Any
  exceptions that are raised by a callback are rescued, logged, and reported to
  any registered `on_error` callbacks.

  The following callbacks are available:
  - `on_client_ready`: This event is sent when the SDK reaches the ready state.
    If the SDK is set up with lazy load or manual polling it's considered ready
    right after instantiation. If it's using auto polling, the ready state is
    reached when the SDK has a valid config JSON loaded into memory either from
    cache or from HTTP.
  - `on_config_changed(config: map())`: This event is sent when the SDK loads a
    valid config JSON into memory from cache, and each subsequent time when the
    loaded config JSON changes via HTTP.
  - `on_flag_evaluated(evaluation_details: EvaluationDetails.t())`: This event
    is sent each time when the SDK evaluates a feature flag or setting. The
    event sends the same evaluation details that you would get from
    get_value_details.
  - on_error(error: String.t()): This event is sent when an error occurs within the
    ConfigCat SDK.
  """
  use TypedStruct

  alias ConfigCat.Config
  alias ConfigCat.EvaluationDetails

  require Logger

  @type on_client_ready_callback :: (() -> term()) | mfa()
  @type on_config_changed_callback :: (Config.t() -> term()) | mfa()
  @type on_error_callback :: (String.t() -> term()) | mfa()
  @type on_flag_evaluated_callback :: (EvaluationDetails.t() -> term()) | mfa()
  @type option ::
          {:on_client_ready, on_client_ready_callback()}
          | {:on_config_changed, on_config_changed_callback()}
          | {:on_error, on_error_callback()}
          | {:on_flag_evaluated, on_flag_evaluated_callback()}

  typedstruct opaque: true do
    field :on_client_ready, [on_client_ready_callback()], default: []
    field :on_config_changed, [on_config_changed_callback()], default: []
    field :on_error, [on_error_callback()], default: []
    field :on_flag_evaluated, [on_flag_evaluated_callback()], default: []
  end

  @doc """
  Create a new `ConfigCat.Hooks` struct with the given callbacks.
  """
  @spec new([option]) :: t()
  def new(options \\ []) do
    hooks = Enum.map(options, fn {key, value} -> {key, List.wrap(value)} end)
    struct!(__MODULE__, hooks)
  end

  @doc """
  Add an `on_client_ready` callback.
  """
  @spec add_on_client_ready(t(), on_client_ready_callback()) :: t()
  def add_on_client_ready(%__MODULE__{} = hooks, callback) do
    Map.update!(hooks, :on_client_ready, &[callback | &1])
  end

  @doc """
  Add an `on_config_changed` callback.
  """
  @spec add_on_config_changed(t(), on_config_changed_callback()) :: t()
  def add_on_config_changed(%__MODULE__{} = hooks, callback) do
    Map.update!(hooks, :on_config_changed, &[callback | &1])
  end

  @doc """
  Add an `on_error` callback.
  """
  @spec add_on_error(t(), on_error_callback()) :: t()
  def add_on_error(%__MODULE__{} = hooks, callback) do
    Map.update!(hooks, :on_error, &[callback | &1])
  end

  @doc """
  Add an `on_flag_evaluated` callback.
  """
  @spec add_on_flag_evaluated(t(), on_flag_evaluated_callback()) :: t()
  def add_on_flag_evaluated(%__MODULE__{} = hooks, callback) do
    Map.update!(hooks, :on_flag_evaluated, &[callback | &1])
  end

  @doc false
  @spec invoke_on_client_ready(t()) :: :ok
  def invoke_on_client_ready(%__MODULE__{} = hooks) do
    invoke_callbacks(hooks, :on_client_ready, [])
  end

  @doc false
  @spec invoke_on_config_changed(t(), Config.t()) :: :ok
  def invoke_on_config_changed(%__MODULE__{} = hooks, config) do
    invoke_callbacks(hooks, :on_config_changed, [config])
  end

  @doc false
  @spec invoke_on_error(t(), String.t()) :: :ok
  def invoke_on_error(%__MODULE__{} = hooks, message) do
    invoke_callbacks(hooks, :on_error, [message])
  end

  @doc false
  @spec invoke_on_flag_evaluated(t(), EvaluationDetails.t()) :: :ok
  def invoke_on_flag_evaluated(%__MODULE__{} = hooks, %EvaluationDetails{} = details) do
    invoke_callbacks(hooks, :on_flag_evaluated, [details])
  end

  defp invoke_callbacks(hooks, name, args) do
    hooks
    |> Map.fetch!(name)
    |> Enum.each(fn callback ->
      try do
        invoke_callback(callback, args)
      rescue
        e ->
          error = "Exception occurred during invoke_#{name} callback: #{inspect(e)}"

          unless name == :on_error do
            Logger.error(error)
            invoke_on_error(hooks, error)
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
