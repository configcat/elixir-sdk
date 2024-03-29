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
  alias ConfigCat.Hooks.Impl

  defmodule State do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :impl, Impl.t()
      field :instance_id, ConfigCat.instance_id(), enforce: true
    end

    @spec new(keyword()) :: t()
    def new(options \\ []) do
      hooks = Keyword.get(options, :hooks, [])

      struct!(__MODULE__, impl: Impl.new(hooks), instance_id: options[:instance_id])
    end

    @spec with_impl(t(), Impl.t()) :: t()
    def with_impl(%__MODULE__{} = state, %Impl{} = impl) do
      %{state | impl: impl}
    end
  end

  @typedoc """
  A hook callback is either an anonymous function or a module/function name/extra_arguments tuple.

  Each callback is passed specific arguments. These specific arguments are
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
  ```
  """
  @type named_callback :: {module(), atom(), list()}
  @type on_client_ready_callback :: (-> any()) | named_callback()
  @type on_config_changed_callback :: (Config.settings() -> any()) | named_callback()
  @type on_error_callback :: (String.t() -> any()) | named_callback()
  @type on_flag_evaluated_callback :: (EvaluationDetails.t() -> any()) | named_callback()
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

    GenServer.start_link(__MODULE__, State.new(options), name: via_tuple(instance_id))
  end

  @doc """
  Add an `on_client_ready` callback.
  """
  @spec add_on_client_ready(t(), on_client_ready_callback()) :: t()
  def add_on_client_ready(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_client_ready, callback})

    instance_id
  end

  @doc """
  Add an `on_config_changed` callback.
  """
  @spec add_on_config_changed(t(), on_config_changed_callback()) :: t()
  def add_on_config_changed(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_config_changed, callback})

    instance_id
  end

  @doc """
  Add an `on_error` callback.
  """
  @spec add_on_error(t(), on_error_callback()) :: t()
  def add_on_error(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_error, callback})

    instance_id
  end

  @doc """
  Add an `on_flag_evaluated` callback.
  """
  @spec add_on_flag_evaluated(t(), on_flag_evaluated_callback()) :: t()
  def add_on_flag_evaluated(instance_id, callback) do
    instance_id
    |> via_tuple()
    |> GenServer.call({:add_hook, :on_flag_evaluated, callback})

    instance_id
  end

  @doc false
  @spec invoke_on_client_ready(t()) :: :ok
  def invoke_on_client_ready(instance_id) do
    instance_id
    |> hooks()
    |> Impl.invoke_hook(:on_client_ready, [])
  end

  @doc false
  @spec invoke_on_config_changed(t(), Config.settings()) :: :ok
  def invoke_on_config_changed(instance_id, settings) do
    instance_id
    |> hooks()
    |> Impl.invoke_hook(:on_config_changed, [settings])
  end

  @doc false
  @spec invoke_on_error(t(), String.t()) :: :ok
  def invoke_on_error(instance_id, message) do
    instance_id
    |> hooks()
    |> Impl.invoke_hook(:on_error, [message])
  end

  @doc false
  @spec invoke_on_flag_evaluated(t(), EvaluationDetails.t()) :: :ok
  def invoke_on_flag_evaluated(instance_id, %EvaluationDetails{} = details) do
    instance_id
    |> hooks()
    |> Impl.invoke_hook(:on_flag_evaluated, [details])
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
    Logger.metadata(instance_id: state.instance_id)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:add_hook, hook, callback}, _from, %State{} = state) do
    new_impl = Impl.add_hook(state.impl, hook, callback)
    {:reply, :ok, State.with_impl(state, new_impl)}
  end

  @impl GenServer
  def handle_call(:hooks, _from, %State{} = state) do
    {:reply, state.impl, state}
  end
end
