defmodule ConfigCat.HooksTest do
  use ConfigCat.CachePolicyCase, async: true

  import Mox

  alias ConfigCat.CachePolicy
  alias ConfigCat.Client
  alias ConfigCat.Config
  alias ConfigCat.Config.TargetingRule
  alias ConfigCat.ConfigEntry
  alias ConfigCat.EvaluationDetails
  alias ConfigCat.Factory
  alias ConfigCat.Hooks
  alias ConfigCat.MockFetcher
  alias ConfigCat.NullDataSource
  alias ConfigCat.User

  require ConfigCat.Config.SettingType, as: SettingType

  @moduletag capture_log: true

  @config Config.inline_salt_and_segments(Factory.config())
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

    settings = Config.settings(@config)

    assert value == "testValue"
    assert_received :on_client_ready
    assert_received {:on_config_changed, ^settings}
    assert_received {:on_flag_evaluated, _details}

    refute_received {:on_error, _error}
    refute_received _any_other_messages
  end

  test "calls subscribed hooks" do
    test_pid = self()

    {:ok, instance_id} = start_hooks()

    _hooks =
      [client: instance_id]
      |> ConfigCat.hooks()
      |> Hooks.add_on_client_ready({TestHooks, :on_client_ready, [test_pid]})
      |> Hooks.add_on_config_changed({TestHooks, :on_config_changed, [test_pid]})
      |> Hooks.add_on_flag_evaluated({TestHooks, :on_flag_evaluated, [test_pid]})
      |> Hooks.add_on_error({TestHooks, :on_error, [test_pid]})

    :ok = start_client(instance_id: instance_id)

    value = ConfigCat.get_value("testStringKey", "", client: instance_id)

    settings = Config.settings(@config)

    assert value == "testValue"
    assert_received :on_client_ready
    assert_received {:on_config_changed, ^settings}
    assert_received {:on_flag_evaluated, _details}
    refute_received {:on_error, _error}
    refute_received _any_other_messages
  end

  test "provides details on on_flag_evaluated hook" do
    stub(MockFetcher, :fetch, fn _instance_id, _etag -> {:ok, ConfigEntry.new(@config, "NEW-ETAG")} end)
    test_pid = self()

    {:ok, instance_id} =
      start_hooks(on_flag_evaluated: {TestHooks, :on_flag_evaluated, [test_pid]})

    :ok = start_client(instance_id: instance_id)

    :ok = ConfigCat.force_refresh(client: instance_id)

    user = User.new("test@test1.com")
    value = ConfigCat.get_value("testStringKey", "", user, client: instance_id)

    assert value == "fake1"

    assert_received {:on_flag_evaluated, details}

    assert %EvaluationDetails{
             default_value?: false,
             error: nil,
             key: "testStringKey",
             matched_targeting_rule: rule,
             matched_percentage_option: nil,
             user: ^user,
             value: "fake1",
             variation_id: "id1"
           } = details

    assert TargetingRule.value(rule, SettingType.string()) == "fake1"
    assert TargetingRule.variation_id(rule) == "id1"
  end

  test "doesn't fail when callbacks raise errors" do
    stub(MockFetcher, :fetch, fn _instance_id, _etag -> {:ok, ConfigEntry.new(@config, "NEW-ETAG")} end)
    callback0 = fn -> raise "Error raised in callback" end
    callback1 = fn _ignored -> raise "Error raised in callback" end

    {:ok, instance_id} =
      start_hooks(
        on_client_ready: callback0,
        on_config_changed: callback1,
        on_flag_evaluated: callback1,
        on_error: callback1
      )

    :ok = start_client(instance_id: instance_id)

    :ok = ConfigCat.force_refresh(client: instance_id)

    assert "testValue" == ConfigCat.get_value("testStringKey", "", client: instance_id)
    assert "default" == ConfigCat.get_value("", "default", client: instance_id)
  end

  defp start_hooks(config \\ []) do
    instance_id = String.to_atom(UUID.uuid4())

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
