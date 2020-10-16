defmodule ConfigCat.FetchPolicyTest do
  use ExUnit.Case, async: true

  alias ConfigCat.FetchPolicy

  describe "checking whether a fetch is required" do
    test "is not required for a manual policy" do
      policy = FetchPolicy.manual()

      refute FetchPolicy.needs_fetch?(policy, DateTime.utc_now())
    end

    test "is not required for an auto policy" do
      policy = FetchPolicy.auto()

      refute FetchPolicy.needs_fetch?(policy, DateTime.utc_now())
    end

    test "is required for a lazy policy when not yet fetched" do
      policy = FetchPolicy.lazy(cache_expiry_seconds: 60)

      assert FetchPolicy.needs_fetch?(policy, nil)
    end

    test "is required for a lazy policy when cache has expired" do
      one_minute_ago = DateTime.add(DateTime.utc_now(), -60, :second)
      policy = FetchPolicy.lazy(cache_expiry_seconds: 60)

      assert FetchPolicy.needs_fetch?(policy, one_minute_ago)
    end

    test "is not required for a lazy policy when cache has not expired" do
      a_few_seconds_ago = DateTime.add(DateTime.utc_now(), -3, :second)
      policy = FetchPolicy.lazy(cache_expiry_seconds: 60)

      refute FetchPolicy.needs_fetch?(policy, a_few_seconds_ago)
    end
  end

  describe "creating auto fetch policy" do
    test "returns with valid interval" do
      actual = FetchPolicy.auto(poll_interval_seconds: -1)

      assert actual.poll_interval_seconds == 1
    end

    test "returns with valid defaults" do
      actual = FetchPolicy.auto()

      assert actual.poll_interval_seconds == 60
      assert actual.type == :auto
    end
  end

  describe "checking to schedule initial fetch" do
    test "returns true if auto policy" do
      policy = FetchPolicy.auto()
      assert FetchPolicy.schedule_initial_fetch?(policy)
    end

    test "returns false if manual policy" do
      policy = FetchPolicy.manual()

      refute FetchPolicy.schedule_initial_fetch?(policy)
    end

    test "returns false if lazy policy" do
      policy = FetchPolicy.lazy(cache_expiry_seconds: 60)

      refute FetchPolicy.schedule_initial_fetch?(policy)
    end
  end

  describe "scheduling next fetch" do
    test "sends a refresh message after poll interval" do
      interval_seconds = 0
      policy = FetchPolicy.auto() |> Map.put(:poll_interval_seconds, interval_seconds)
      FetchPolicy.schedule_next_fetch(policy, self())

      start = DateTime.utc_now()
      assert_receive :refresh
      stop = DateTime.utc_now()
      time_passed = DateTime.diff(stop, start)
      assert time_passed == interval_seconds
    end

    test "doesnt send a refresh message for manual policy" do
      policy = FetchPolicy.manual()
      FetchPolicy.schedule_next_fetch(policy, self())

      refute_receive :refresh
    end

    test "doesnt send a refresh message for lazy policy" do
      policy = FetchPolicy.lazy(cache_expiry_seconds: 1)
      FetchPolicy.schedule_next_fetch(policy, self())

      refute_receive :refresh
    end
  end
end
