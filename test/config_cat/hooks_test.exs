defmodule ConfigCat.HooksTest do
  use ConfigCat.CachePolicyCase, async: true

  import Jason.Sigil

  alias ConfigCat.CachePolicy
  alias ConfigCat.Client
  alias ConfigCat.ConfigEntry
  alias ConfigCat.Hooks
  alias ConfigCat.NullDataSource

  @moduletag capture_log: true

  @config ~J"""
  {
    "p": {
      "u": "https://cdn-global.configcat.com",
      "r": 0
    },
    "f": {
      "testBoolKey": {"v": true,"t": 0, "p": [],"r": []},
      "testStringKey": {"v": "testValue", "i": "id", "t": 1, "p": [],"r": [
        {"i":"id1","v":"fake1","a":"Identifier","t":2,"c":"@test1.com"},
        {"i":"id2","v":"fake2","a":"Identifier","t":2,"c":"@test2.com"}
      ]},
      "testIntKey": {"v": 1,"t": 2, "p": [],"r": []},
      "testDoubleKey": {"v": 1.1,"t": 3,"p": [],"r": []},
      "key1": {"v": true, "i": "fakeId1","p": [], "r": []},
      "key2": {"v": false, "i": "fakeId2","p": [], "r": []}
    }
  }
  """
  @policy CachePolicy.manual()

  defmodule TestHooks do
    @moduledoc false
    alias ConfigCat.Config
    alias ConfigCat.EvaluationDetails

    @spec on_client_ready(pid()) :: :ok
    def on_client_ready(test_pid) do
      send(test_pid, :on_client_ready)
      :ok
    end

    @spec on_config_changed(Config.t(), pid()) :: :ok
    def on_config_changed(config, test_pid) do
      send(test_pid, {:on_config_changed, config})
      :ok
    end

    @spec on_flag_evaluated(EvaluationDetails.t(), pid()) :: :ok
    def on_flag_evaluated(%EvaluationDetails{} = details, test_pid) do
      send(test_pid, {:on_flag_evaluated, details})
      :ok
    end

    @spec on_error(String.t(), pid()) :: :ok
    def on_error(message, test_pid) do
      send(test_pid, {:on_error, message})
      :ok
    end
  end

  test "calls initial hooks" do
    test_pid = self()

    {:ok, instance_id} =
      start_hooks(
        on_client_ready: {TestHooks, :on_client_ready, [test_pid]},
        on_config_changed: {TestHooks, :on_config_changed, [test_pid]},
        on_flag_evaluated: {TestHooks, :on_flag_evaluated, [test_pid]},
        on_error: {TestHooks, :on_error, [test_pid]}
      )

    :ok = start_client(instance_id: instance_id)

    value = ConfigCat.get_value("testStringKey", "", client: instance_id)

    assert value == "testValue"
    assert_received :on_client_ready
  end

  test "calls subscribed hooks" do
    test_pid = self()

    {:ok, instance_id} = start_hooks()

    _hooks =
      ConfigCat.hooks(client: instance_id)
      |> Hooks.add_on_client_ready({TestHooks, :on_client_ready, [test_pid]})
      |> Hooks.add_on_config_changed({TestHooks, :on_config_changed, [test_pid]})
      |> Hooks.add_on_flag_evaluated({TestHooks, :on_flag_evaluated, [test_pid]})
      |> Hooks.add_on_error({TestHooks, :on_error, [test_pid]})

    :ok = start_client(instance_id: instance_id)

    value = ConfigCat.get_value("testStringKey", "", client: instance_id)

    assert value == "testValue"
    assert_received :on_client_ready
  end

  defp start_hooks(config \\ []) do
    instance_id = UUID.uuid4() |> String.to_atom()

    start_supervised!({Hooks, hooks: config, instance_id: instance_id})

    {:ok, instance_id}
  end

  defp start_client(opts) do
    initial_entry =
      Keyword.get_lazy(opts, :initial_entry, fn ->
        ConfigEntry.new(@config, "test-etag")
      end)

    instance_id = opts[:instance_id]

    {:ok, instance_id} =
      start_cache_policy(@policy,
        initial_entry: initial_entry,
        instance_id: instance_id,
        start_hooks?: false
      )

    client_options = [
      flag_overrides: NullDataSource.new(),
      instance_id: instance_id
    ]

    start_supervised!({Client, client_options})

    :ok
  end
end
