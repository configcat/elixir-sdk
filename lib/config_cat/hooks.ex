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
  use GenServer

  alias ConfigCat.Config
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.Hooks.State

  @typedoc """
  A module/function name/extra arguments tuple representing a callback function.

  Each callback passes specific arguments. These specific arguments are
  prepended to the extra arguments provided in the tuple (if any).

  For example, you might want to define a callback that sends a message to
  another process which the config changes. You can pass the pid of that process
  as an extra argument:

  ```elixir
  def MyModule do
    def subscribe_to_config_changes(subscriber_pid) do
      ConfigCat.hooks()
      |> ConfigCat.Hooks.add_on_config_changed({__MODULE__, :on_config_changed, [subscriber_pid]})
    end

    def on_config_changed(config, pid) do
      send pid, {:config_changed, config}
    end
  end
  """
  @type named_callback :: {module(), atom(), list()}
  @type on_client_ready_callback :: (() -> term()) | named_callback()
  @type on_config_changed_callback :: (Config.t() -> term()) | named_callback()
  @type on_error_callback :: (String.t() -> term()) | named_callback()
  @type on_flag_evaluated_callback :: (EvaluationDetails.t() -> term()) | named_callback()
  @type option ::
          {:on_client_ready, on_client_ready_callback()}
          | {:on_config_changed, on_config_changed_callback()}
          | {:on_error, on_error_callback()}
          | {:on_flag_evaluated, on_flag_evaluated_callback()}
  @type start_option :: {:hooks, t()} | {:instance_id, ConfigCat.instance_id()}
  @opaque t :: ConfigCat.instance_id()

  @doc false
  @spec start_link([start_option()]) :: GenServer.on_start()
  def start_link(options) do
    instance_id = Keyword.fetch!(options, :instance_id)
    hooks = Keyword.get(options, :hooks, [])

    GenServer.start_link(__MODULE__, State.new(hooks), name: via_tuple(instance_id))
  end

  @doc """
  Add an `on_client_ready` callback.
  """
  @spec add_on_client_ready(t(), on_client_ready_callback()) :: :ok
  def add_on_client_ready(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_client_ready, callback})
  end

  @doc """
  Add an `on_config_changed` callback.
  """
  @spec add_on_config_changed(t(), on_config_changed_callback()) :: :ok
  def add_on_config_changed(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_config_changed, callback})
  end

  @doc """
  Add an `on_error` callback.
  """
  @spec add_on_error(t(), on_error_callback()) :: :ok
  def add_on_error(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_error, callback})
  end

  @doc """
  Add an `on_flag_evaluated` callback.
  """
  @spec add_on_flag_evaluated(t(), on_flag_evaluated_callback()) :: :ok
  def add_on_flag_evaluated(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_flag_evaluated, callback})
  end

  @doc false
  @spec invoke_on_client_ready(t()) :: :ok
  def invoke_on_client_ready(instance_id) do
    instance_id
    |> hooks()
    |> State.invoke_hook(:on_client_ready, [])
  end

  @doc false
  @spec invoke_on_config_changed(t(), Config.t()) :: :ok
  def invoke_on_config_changed(instance_id, config) do
    instance_id
    |> hooks()
    |> State.invoke_hook(:on_config_changed, [config])
  end

  @doc false
  @spec invoke_on_error(t(), String.t()) :: :ok
  def invoke_on_error(instance_id, message) do
    instance_id
    |> hooks()
    |> State.invoke_hook(:on_error, [message])
  end

  @doc false
  @spec invoke_on_flag_evaluated(t(), EvaluationDetails.t()) :: :ok
  def invoke_on_flag_evaluated(instance_id, %EvaluationDetails{} = details) do
    instance_id
    |> hooks()
    |> State.invoke_hook(:on_flag_evaluated, [details])
  end

  defp hooks(instance_id) do
    instance_id
    |> via_tuple()
    |> GenServer.call(:hooks)
  end

  defp via_tuple(instance_id) do
    {:via, Registry, {ConfigCat.Registry, {__MODULE__, instance_id}}}
  end

  @impl GenServer
  def init(%State{} = state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:add_hook, hook, callback}, _from, %State{} = state) do
    new_state = State.add_hook(state, hook, callback)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:hooks, _from, %State{} = state) do
    {:reply, state, state}
  end
end
