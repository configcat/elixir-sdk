defmodule ConfigCat.ClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias ConfigCat.{Client, Constants, MockCachePolicy}

  require ConfigCat.Constants

  @cache_policy_id :cache_policy_id

  setup :verify_on_exit!

  setup do
    feature = "FEATURE"
    value = "VALUE"
    variation = "VARIATION"

    config = %{
      Constants.feature_flags() => %{
        feature => %{
          Constants.variation_id() => variation,
          Constants.value() => value
        }
      }
    }

    {:ok, config: config, feature: feature, value: value, variation: variation}
  end

  describe "when the configuration has been fetched" do
    setup %{config: config} do
      {:ok, client} = start_client()

      MockCachePolicy
      |> stub(:get, fn @cache_policy_id -> {:ok, config} end)

      {:ok, client: client}
    end

    test "get_all_keys/1 returns all known keys", %{
      client: client,
      feature: feature
    } do
      assert Client.get_all_keys(client) == [feature]
    end

    test "get_value/4 looks up the value for a key", %{
      client: client,
      feature: feature,
      value: value
    } do
      assert Client.get_value(client, feature, "default") == value
    end

    test "get_variation_id/4 looks up the variation id for a key", %{
      client: client,
      feature: feature,
      variation: variation
    } do
      assert Client.get_variation_id(client, feature, "default") == variation
    end
  end

  describe "when the configuration has not been fetched" do
    setup do
      {:ok, client} = start_client()

      MockCachePolicy
      |> stub(:get, fn @cache_policy_id -> {:error, :not_found} end)

      {:ok, client: client}
    end

    test "get_all_keys/1 returns an empty list of keys", %{client: client} do
      assert Client.get_all_keys(client) == []
    end

    test "get_value/4 returns default value", %{client: client} do
      assert Client.get_value(client, "any_feature", "default") == "default"
    end

    test "get_variation_id/4 returns default variation", %{client: client} do
      assert Client.get_variation_id(client, "any_feature", "default") == "default"
    end
  end

  defp start_client do
    name = UUID.uuid4() |> String.to_atom()

    options = [
      cache_policy: MockCachePolicy,
      cache_policy_id: @cache_policy_id,
      name: name
    ]

    {:ok, _pid} = Client.start_link(options)

    allow(MockCachePolicy, self(), name)

    {:ok, name}
  end
end
