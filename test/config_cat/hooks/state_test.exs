defmodule ConfigCat.Hooks.StateTest do
  use ExUnit.Case, async: true

  alias ConfigCat.Config
  alias ConfigCat.Hooks.State

  test "calls initial hook when invoked" do
    callback = fn ->
      send(self(), :on_client_ready_called)
    end

    state = State.new(on_client_ready: callback)

    assert :ok = State.invoke_hook(state, :on_client_ready, [])
    assert_received :on_client_ready_called
  end

  test "calls subscribed hook when invoked" do
    message = "Some error message"

    callback = fn msg ->
      send(self(), {:on_error_called, msg})
    end

    state =
      State.new()
      |> State.add_hook(:on_error, callback)

    assert :ok = State.invoke_hook(state, :on_error, [message])
    assert_received {:on_error_called, ^message}
  end

  test "calls multiple hooks" do
    callback1 = fn -> send(self(), :callback1_called) end
    callback2 = fn -> send(self(), :callback2_called) end

    state =
      State.new(on_client_ready: callback1)
      |> State.add_hook(:on_client_ready, callback2)

    assert :ok = State.invoke_hook(state, :on_client_ready, [])

    assert_received :callback1_called
    assert_received :callback2_called
  end

  @tag capture_log: true
  test "calls later hooks even when earlier one fails" do
    fail_callback = fn -> raise "Callback failed" end
    good_callback = fn -> send(self(), :good_callback_called) end

    state =
      State.new(on_client_ready: fail_callback)
      |> State.add_hook(:on_client_ready, good_callback)

    assert :ok = State.invoke_hook(state, :on_client_ready, [])

    assert_received :good_callback_called
  end

  @tag capture_log: true
  test "calls on_error hook when other hook fails" do
    message = "Callback failed"
    fail_callback = fn -> raise message end
    on_error_callback = fn msg -> send(self(), {:on_error_called, msg}) end

    state = State.new(on_client_ready: fail_callback, on_error: on_error_callback)

    assert :ok = State.invoke_hook(state, :on_client_ready, [])

    assert_received {:on_error_called, received}
    assert received =~ message
  end

  @tag capture_log: true
  @tag timeout: 1_000
  test "does not call on_error hook recursively" do
    fail_callback = fn _msg -> raise "Callback failed" end

    state = State.new(on_error: fail_callback)

    assert :ok = State.invoke_hook(state, :on_error, ["Some error"])

    # If this test finishes without timing out, we successfully avoided an
    # infinite recursion of calling the failed on_error callback.
  end

  test "allows module/function/extra args as a hook" do
    state = State.new(on_client_ready: {__MODULE__, :on_client_ready, []})

    assert :ok = State.invoke_hook(state, :on_client_ready, [])

    assert_received :on_client_ready_mfa_called
  end

  test "passes extra args to mfa hook callback" do
    config = %{"some" => "config"}
    state = State.new(on_config_changed: {__MODULE__, :on_config_changed, [42, "string"]})

    assert :ok = State.invoke_hook(state, :on_config_changed, [config])

    assert_received {:on_config_changed_called, ^config, 42, "string"}
  end

  @spec on_client_ready :: :ok
  def on_client_ready do
    send(self(), :on_client_ready_mfa_called)
    :ok
  end

  @spec on_config_changed(Config.t(), number(), String.t()) :: :ok
  def on_config_changed(config, extra_number, extra_string) do
    send(self(), {:on_config_changed_called, config, extra_number, extra_string})
  end
end
