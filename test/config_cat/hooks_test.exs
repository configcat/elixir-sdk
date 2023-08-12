defmodule ConfigCat.HooksTest do
  use ExUnit.Case, async: true

  alias ConfigCat.Hooks

  test "calls initial hook when invoked" do
    callback = fn ->
      send(self(), :on_client_ready_called)
    end

    hooks = Hooks.new(on_client_ready: callback)

    assert :ok = Hooks.invoke_on_client_ready(hooks)
    assert_received :on_client_ready_called
  end

  test "calls subscribed hook when invoked" do
    message = "Some error message"

    callback = fn msg ->
      send(self(), {:on_error_called, msg})
    end

    hooks =
      Hooks.new()
      |> Hooks.add_on_error(callback)

    assert :ok = Hooks.invoke_on_error(hooks, message)
    assert_received {:on_error_called, ^message}
  end

  test "calls multiple hooks" do
    callback1 = fn -> send(self(), :callback1_called) end
    callback2 = fn -> send(self(), :callback2_called) end

    hooks =
      Hooks.new(on_client_ready: callback1)
      |> Hooks.add_on_client_ready(callback2)

    assert :ok = Hooks.invoke_on_client_ready(hooks)

    assert_received :callback1_called
    assert_received :callback2_called
  end

  @tag capture_log: true
  test "calls later hooks even when earlier one fails" do
    fail_callback = fn -> raise "Callback failed" end
    good_callback = fn -> send(self(), :good_callback_called) end

    hooks =
      Hooks.new(on_client_ready: fail_callback)
      |> Hooks.add_on_client_ready(good_callback)

    assert :ok = Hooks.invoke_on_client_ready(hooks)

    assert_received :good_callback_called
  end

  @tag capture_log: true
  test "calls on_error hook when other hook fails" do
    message = "Callback failed"
    fail_callback = fn -> raise message end
    on_error_callback = fn msg -> send(self(), {:on_error_called, msg}) end

    hooks = Hooks.new(on_client_ready: fail_callback, on_error: on_error_callback)

    assert :ok = Hooks.invoke_on_client_ready(hooks)

    assert_received {:on_error_called, received}
    assert received =~ message
  end

  @tag capture_log: true
  @tag timeout: 1_000
  test "does not call on_error hook recursively" do
    fail_callback = fn _msg -> raise "Callback failed" end

    hooks = Hooks.new(on_error: fail_callback)

    assert :ok = Hooks.invoke_on_error(hooks, "Some error")

    # If this test finishes without timing out, we successfully avoided an
    # infinite recursion of calling the failed on_error callback.
  end

  test "allows module/function/arity as a hook" do
    hooks = Hooks.new(on_client_ready: {__MODULE__, :on_client_ready, 0})

    assert :ok = Hooks.invoke_on_client_ready(hooks)

    assert_received :on_client_ready_mfa_called
  end

  @tag capture_log: true
  test "fails if module/function/arity hook has wrong arity" do
    on_error = fn message -> send(self(), {:on_error, message}) end
    hooks = Hooks.new(on_config_changed: {__MODULE__, :on_client_ready, 0}, on_error: on_error)

    assert :ok = Hooks.invoke_on_config_changed(hooks, %{})

    assert_received {:on_error, message}
    assert message =~ "has incorrect arity"
  end

  @spec on_client_ready :: :ok
  def on_client_ready do
    send(self(), :on_client_ready_mfa_called)
    :ok
  end
end
