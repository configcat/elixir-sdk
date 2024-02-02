defmodule ConfigCat.Config.UserComparatorTest do
  @moduledoc """
  All evaluators are tested exhaustively in ConfigCat.RolloutTest.
  These are basic tests to ensure that we're using the correct
  comparator type for the given comparator value.
  """

  use ExUnit.Case, async: true

  alias ConfigCat.Config.ComparisonContext
  alias ConfigCat.Config.UserComparator
  alias ConfigCat.Config.UserCondition

  @context_salt "CONTEXT_SALT"
  @salt "SALT"

  test "returns false if given an unknown comparator" do
    assert {:ok, false} = compare(-1, "b", ["a", "b", "c"])
  end

  describe "basic comparators" do
    test "is_one_of" do
      is_one_of = 0

      assert {:ok, true} = compare(is_one_of, "b", ["a", "b", "c"])
      assert {:ok, false} = compare(is_one_of, "x", ["a", "b", "c"])
    end

    test "is_not_one_of" do
      is_not_one_of = 1

      assert {:ok, false} = compare(is_not_one_of, "b", ["a", "b", "c"])
      assert {:ok, true} = compare(is_not_one_of, "x", ["a", "b", "c"])
    end

    test "contains_any_of" do
      contains_any_of = 2

      assert {:ok, true} = compare(contains_any_of, "jane@configcat.com", ["configcat.com", "example.com"])
      assert {:ok, true} = compare(contains_any_of, "jane@example.com", ["configcat.com", "example.com"])
      assert {:ok, false} = compare(contains_any_of, "jane@email.com", ["configcat.com"])
    end

    test "not_contains_any_of" do
      not_contains_any_of = 3

      assert {:ok, false} =
               compare(not_contains_any_of, "jane@configcat.com", ["configcat.com", "example.com"])

      assert {:ok, false} =
               compare(not_contains_any_of, "jane@example.com", ["configcat.com", "example.com"])

      assert {:ok, true} =
               compare(not_contains_any_of, "jane@email.com", ["configcat.com"])
    end

    test "equals" do
      equals = 28

      assert {:ok, true} = compare(equals, "abc", "abc")
      assert {:ok, false} = compare(equals, "abc", "def")
    end

    test "not equals" do
      not_equals = 29

      assert {:ok, true} = compare(not_equals, "abc", "def")
      assert {:ok, false} = compare(not_equals, "abc", "abc")
    end

    test "starts_with_any_of" do
      starts_with_any_of = 30
      comparison = ["a", "b", "c"]

      assert {:ok, true} = compare(starts_with_any_of, "apple", comparison)
      assert {:ok, true} = compare(starts_with_any_of, "banana", comparison)
      assert {:ok, true} = compare(starts_with_any_of, "cherry", comparison)
      assert {:ok, true} = compare(starts_with_any_of, "a", comparison)
      assert {:ok, false} = compare(starts_with_any_of, "pear", comparison)
      assert {:ok, false} = compare(starts_with_any_of, "", comparison)
    end

    test "not starts_with_any_of" do
      not_starts_with_any_of = 31
      comparison = ["a", "b", "c"]

      assert {:ok, true} = compare(not_starts_with_any_of, "pear", comparison)
      assert {:ok, true} = compare(not_starts_with_any_of, "", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of, "apple", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of, "banana", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of, "cherry", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of, "a", comparison)
    end

    test "ends_with_any_of" do
      ends_with_any_of = 32
      comparison = ["a", "b", "c"]

      assert {:ok, true} = compare(ends_with_any_of, "banana", comparison)
      assert {:ok, true} = compare(ends_with_any_of, "thumb", comparison)
      assert {:ok, true} = compare(ends_with_any_of, "sonic", comparison)
      assert {:ok, true} = compare(ends_with_any_of, "a", comparison)
      assert {:ok, false} = compare(ends_with_any_of, "pear", comparison)
      assert {:ok, false} = compare(ends_with_any_of, "", comparison)
    end

    test "not ends_with_any_of" do
      not_ends_with_any_of = 33
      comparison = ["a", "b", "c"]

      assert {:ok, true} = compare(not_ends_with_any_of, "pear", comparison)
      assert {:ok, true} = compare(not_ends_with_any_of, "", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of, "banana", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of, "thumb", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of, "sonic", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of, "a", comparison)
    end

    test "array_contains_any_of" do
      array_contains_any_of = 34
      comparison = ["a", "b", "c"]

      assert {:ok, true} = compare(array_contains_any_of, ["a", "x"], comparison)
      assert {:ok, true} = compare(array_contains_any_of, ["x", "b"], comparison)
      assert {:ok, true} = compare(array_contains_any_of, ["c"], comparison)
      assert {:ok, true} = compare(array_contains_any_of, Jason.encode!(["c"]), comparison)
      assert {:ok, false} = compare(array_contains_any_of, ["x"], comparison)
      assert {:error, :invalid_string_list} = compare(array_contains_any_of, "a", comparison)
      assert {:error, :invalid_string_list} = compare(array_contains_any_of, :not_a_list, comparison)
    end

    test "array_not_contains_any_of" do
      array_not_contains_any_of = 35
      comparison = ["a", "b", "c"]

      assert {:ok, true} = compare(array_not_contains_any_of, ["x"], comparison)
      assert {:ok, false} = compare(array_not_contains_any_of, ["a", "x"], comparison)
      assert {:ok, false} = compare(array_not_contains_any_of, ["x", "b"], comparison)
      assert {:ok, false} = compare(array_not_contains_any_of, ["c"], comparison)
      assert {:ok, false} = compare(array_not_contains_any_of, Jason.encode!(["c"]), comparison)
      assert {:error, :invalid_string_list} = compare(array_not_contains_any_of, "a", comparison)
      assert {:error, :invalid_string_list} = compare(array_not_contains_any_of, :not_a_list, comparison)
    end
  end

  describe "semantic version comparators" do
    test "is_one_of (semver)" do
      is_one_of_semver = 4

      assert {:ok, true} = compare(is_one_of_semver, "1.2.0", ["1.2.0", "1.3.4"])
      assert {:ok, false} = compare(is_one_of_semver, "2.0.0", ["1.2.0", "1.3.4"])

      assert {:error, :invalid_version} =
               compare(is_one_of_semver, "invalid", ["1.2.0", "1.3.4"])

      assert {:error, :invalid_version} =
               compare(is_one_of_semver, "1.2.0", ["invalid", "1.2.0"])

      assert {:error, :invalid_version} =
               compare(is_one_of_semver, "1.2.0", ["1.2.0", "invalid"])
    end

    test "is_not_one_of (semver)" do
      is_not_one_of_semver = 5

      assert {:ok, true} = compare(is_not_one_of_semver, "2.0.0", ["1.2.0", "1.3.4"])
      assert {:ok, false} = compare(is_not_one_of_semver, "1.2.0", ["1.2.0", "1.3.4"])

      assert {:error, :invalid_version} =
               compare(is_not_one_of_semver, "invalid", ["1.2.0", "1.3.4"])

      assert {:error, :invalid_version} =
               compare(is_not_one_of_semver, "1.2.0", ["invalid", "1.3.4"])

      assert {:error, :invalid_version} =
               compare(is_not_one_of_semver, "1.2.0", ["1.2.0", "invalid"])
    end

    test "< (SemVer)" do
      less_than_semver = 6

      assert {:ok, true} = compare(less_than_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = compare(less_than_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = compare(less_than_semver, "1.2.0", "1.2.0")

      assert {:error, :invalid_version} =
               compare(less_than_semver, "invalid", "1.2.0")

      assert {:error, :invalid_version} =
               compare(less_than_semver, "1.3.0", "invalid")
    end

    test "<= (SemVer)" do
      less_than_equal_semver = 7

      assert {:ok, true} = compare(less_than_equal_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = compare(less_than_equal_semver, "1.3.0", "1.2.0")
      assert {:ok, true} = compare(less_than_equal_semver, "1.2.0", "1.2.0")

      assert {:error, :invalid_version} =
               compare(less_than_equal_semver, "invalid", "1.2.0")

      assert {:error, :invalid_version} =
               compare(less_than_equal_semver, "1.3.0", "invalid")
    end

    test "> (SemVer)" do
      greater_than_semver = 8

      assert {:ok, true} = compare(greater_than_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = compare(greater_than_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = compare(greater_than_semver, "1.2.0", "1.2.0")

      assert {:error, :invalid_version} =
               compare(greater_than_semver, "invalid", "1.2.0")

      assert {:error, :invalid_version} =
               compare(greater_than_semver, "1.3.0", "invalid")
    end

    test ">= (SemVer)" do
      greater_than_equal_semver = 9

      assert {:ok, true} = compare(greater_than_equal_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = compare(greater_than_equal_semver, "1.2.0", "1.3.0")
      assert {:ok, true} = compare(greater_than_equal_semver, "1.2.0", "1.2.0")

      assert {:error, :invalid_version} =
               compare(greater_than_equal_semver, "invalid", "1.2.0")

      assert {:error, :invalid_version} =
               compare(greater_than_equal_semver, "1.3.0", "invalid")
    end
  end

  describe "numeric comparators" do
    test "= (Number)" do
      equals_number = 10

      assert {:ok, true} = compare(equals_number, "3.5", "3.5000")
      assert {:ok, true} = compare(equals_number, "3,5", "3.5000")
      assert {:ok, true} = compare(equals_number, 3.5, 3.5000)
      assert {:ok, false} = compare(equals_number, "3,5", "4.752")
      assert {:error, :invalid_float} = compare(equals_number, "not a float", "3.5000")
      assert {:error, :invalid_float} = compare(equals_number, "3,5", "not a float")
    end

    test "<> (Number)" do
      not_equals_number = 11

      assert {:ok, false} = compare(not_equals_number, "3.5", "3.5000")
      assert {:ok, false} = compare(not_equals_number, "3,5", "3.5000")
      assert {:ok, false} = compare(not_equals_number, 3.5, 3.5000)
      assert {:ok, true} = compare(not_equals_number, "3,5", "4.752")

      assert {:error, :invalid_float} =
               compare(not_equals_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               compare(not_equals_number, "3,5", "not a float")
    end

    test "< (Number)" do
      less_than_number = 12

      assert {:ok, true} = compare(less_than_number, "3.5", "3.6000")
      assert {:ok, true} = compare(less_than_number, "3,5", "3.6000")
      assert {:ok, true} = compare(less_than_number, 3.5, 3.6000)
      assert {:ok, false} = compare(less_than_number, "3,5", "1.752")
      assert {:ok, false} = compare(less_than_number, "3,5", "3.5")

      assert {:error, :invalid_float} =
               compare(less_than_number, "not a float", "3.5000")

      assert {:error, :invalid_float} = compare(less_than_number, "3,5", "not a float")
    end

    test "<= (Number)" do
      less_than_equal_number = 13

      assert {:ok, true} = compare(less_than_equal_number, "3.5", "3.6000")
      assert {:ok, true} = compare(less_than_equal_number, "3,5", "3.6000")
      assert {:ok, true} = compare(less_than_equal_number, 3.5, 3.6000)
      assert {:ok, true} = compare(less_than_equal_number, "3,5", "3.5")
      assert {:ok, false} = compare(less_than_equal_number, "3,5", "1.752")

      assert {:error, :invalid_float} =
               compare(less_than_equal_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               compare(less_than_equal_number, "3,5", "not a float")
    end

    test "> (Number)" do
      greater_than_number = 14

      assert {:ok, false} = compare(greater_than_number, "3.5", "3.6000")
      assert {:ok, false} = compare(greater_than_number, "3,5", "3.6000")
      assert {:ok, false} = compare(greater_than_number, 3.5, 3.6000)
      assert {:ok, false} = compare(greater_than_number, "3,5", "3.5")
      assert {:ok, true} = compare(greater_than_number, "3,5", "1.752")

      assert {:error, :invalid_float} =
               compare(greater_than_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               compare(greater_than_number, "3,5", "not a float")
    end

    test ">= (Number)" do
      greater_than_equal_number = 15

      assert {:ok, false} = compare(greater_than_equal_number, "3.5", "3.6000")
      assert {:ok, false} = compare(greater_than_equal_number, "3,5", "3.6000")
      assert {:ok, false} = compare(greater_than_equal_number, 3.5, 3.6000)
      assert {:ok, true} = compare(greater_than_equal_number, "3,5", "1.752")
      assert {:ok, true} = compare(greater_than_equal_number, "3,5", "3.5")

      assert {:error, :invalid_float} =
               compare(greater_than_equal_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               compare(greater_than_equal_number, "3,5", "not a float")
    end
  end

  describe "hashed comparators" do
    setup do
      hashed = %{
        a: "d21ec0ebb63930d047bb48e94674ea2ae07b8c0e7fec9de888f31bb22444be85",
        b: "6f816cafc2729b3f031874ba92e13f05f0b1d9dad3496cecfa2331940aca43be",
        c: "a5dbca52195f5eb637f760d9553f3e45088a447566c4067c9f73746a67b93429"
      }

      {:ok, hashed: hashed}
    end

    test "is_one_of (hashed)", %{hashed: hashed} do
      is_one_of_hashed = 16
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = compare(is_one_of_hashed, "a", [a, b, c])
      assert {:ok, false} = compare(is_one_of_hashed, "x", [a, b, c])
    end

    test "is_not_one_of (hashed)", %{hashed: hashed} do
      is_not_one_of_hashed = 17
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = compare(is_not_one_of_hashed, "x", [a, b, c])
      assert {:ok, false} = compare(is_not_one_of_hashed, "a", [a, b, c])
    end

    test "equals (hashed)", %{hashed: hashed} do
      equals_hashed = 20
      %{a: a} = hashed

      assert {:ok, true} = compare(equals_hashed, "a", a)
      assert {:ok, false} = compare(equals_hashed, "x", a)
    end

    test "not equals (hashed)", %{hashed: hashed} do
      not_equals_hashed = 21
      %{a: a} = hashed

      assert {:ok, true} = compare(not_equals_hashed, "x", a)
      assert {:ok, false} = compare(not_equals_hashed, "a", a)
    end

    test "starts_with_any_of (hashed)", %{hashed: hashed} do
      starts_with_any_of_hashed = 22
      %{a: a, b: b, c: c} = hashed
      comparison = ["1_#{a}", "1_#{b}", "1_#{c}"]

      assert {:ok, true} = compare(starts_with_any_of_hashed, "apple", comparison)
      assert {:ok, true} = compare(starts_with_any_of_hashed, "banana", comparison)
      assert {:ok, true} = compare(starts_with_any_of_hashed, "cherry", comparison)
      assert {:ok, true} = compare(starts_with_any_of_hashed, "a", comparison)
      assert {:ok, false} = compare(starts_with_any_of_hashed, "pear", comparison)
      assert {:ok, false} = compare(starts_with_any_of_hashed, "", comparison)
    end

    test "not starts_with_any_of (hashed)", %{hashed: hashed} do
      not_starts_with_any_of_hashed = 23
      %{a: a, b: b, c: c} = hashed
      comparison = ["1_#{a}", "1_#{b}", "1_#{c}"]

      assert {:ok, true} = compare(not_starts_with_any_of_hashed, "pear", comparison)
      assert {:ok, true} = compare(not_starts_with_any_of_hashed, "", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of_hashed, "apple", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of_hashed, "banana", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of_hashed, "cherry", comparison)
      assert {:ok, false} = compare(not_starts_with_any_of_hashed, "a", comparison)
    end

    test "ends_with_any_of (hashed)", %{hashed: hashed} do
      ends_with_any_of_hashed = 24
      %{a: a, b: b, c: c} = hashed
      comparison = ["1_#{a}", "1_#{b}", "1_#{c}"]

      assert {:ok, true} = compare(ends_with_any_of_hashed, "banana", comparison)
      assert {:ok, true} = compare(ends_with_any_of_hashed, "thumb", comparison)
      assert {:ok, true} = compare(ends_with_any_of_hashed, "sonic", comparison)
      assert {:ok, true} = compare(ends_with_any_of_hashed, "a", comparison)
      assert {:ok, false} = compare(ends_with_any_of_hashed, "pear", comparison)
      assert {:ok, false} = compare(ends_with_any_of_hashed, "", comparison)
    end

    test "not ends_with_any_of (hashed)", %{hashed: hashed} do
      not_ends_with_any_of_hashed = 25
      %{a: a, b: b, c: c} = hashed
      comparison = ["1_#{a}", "1_#{b}", "1_#{c}"]

      assert {:ok, true} = compare(not_ends_with_any_of_hashed, "pear", comparison)
      assert {:ok, true} = compare(not_ends_with_any_of_hashed, "", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of_hashed, "banana", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of_hashed, "thumb", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of_hashed, "sonic", comparison)
      assert {:ok, false} = compare(not_ends_with_any_of_hashed, "a", comparison)
    end

    test "array_contains_any_of (hashed)", %{hashed: hashed} do
      array_contains_any_of_hashed = 26
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = compare(array_contains_any_of_hashed, ["a", "x"], [a, b, c])
      assert {:ok, true} = compare(array_contains_any_of_hashed, ["x", "b"], [a, b, c])
      assert {:ok, true} = compare(array_contains_any_of_hashed, ["c"], [a, b, c])
      assert {:ok, true} = compare(array_contains_any_of_hashed, Jason.encode!(["c"]), [a, b, c])
      assert {:ok, false} = compare(array_contains_any_of_hashed, ["x"], [a, b, c])
      assert {:error, :invalid_string_list} = compare(array_contains_any_of_hashed, "a", [a, b, c])
      assert {:error, :invalid_string_list} = compare(array_contains_any_of_hashed, :not_a_list, [a, b, c])
    end

    test "array_not_contains_any_of (hashed)", %{hashed: hashed} do
      array_not_contains_any_of_hashed = 27
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = compare(array_not_contains_any_of_hashed, ["x"], [a, b, c])
      assert {:ok, false} = compare(array_not_contains_any_of_hashed, ["a", "x"], [a, b, c])
      assert {:ok, false} = compare(array_not_contains_any_of_hashed, ["x", "b"], [a, b, c])
      assert {:ok, false} = compare(array_not_contains_any_of_hashed, ["c"], [a, b, c])
      assert {:ok, false} = compare(array_not_contains_any_of_hashed, Jason.encode!(["c"]), [a, b, c])
      assert {:error, :invalid_string_list} = compare(array_not_contains_any_of_hashed, "a", [a, b, c])
      assert {:error, :invalid_string_list} = compare(array_not_contains_any_of_hashed, :not_a_list, [a, b, c])
    end
  end

  describe "datetime comparators" do
    test "before" do
      before_datetime = 18
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -1, :second)
      later = DateTime.add(now, 1, :second)
      {:ok, now_unix} = UserComparator.to_unix_seconds(now)
      {:ok, earlier_unix} = UserComparator.to_unix_seconds(earlier)

      assert {:ok, true} = compare(before_datetime, earlier, now_unix)
      assert {:ok, true} = compare(before_datetime, earlier_unix, now_unix)
      assert {:ok, true} = compare(before_datetime, DateTime.to_naive(earlier), now_unix)
      assert {:ok, true} = compare(before_datetime, to_string(earlier_unix), now_unix)
      assert {:ok, true} = compare(before_datetime, earlier, to_string(now_unix))
      assert {:ok, false} = compare(before_datetime, now, now_unix)
      assert {:ok, false} = compare(before_datetime, later, now_unix)

      assert {:error, :invalid_datetime} =
               compare(before_datetime, "not a datetime", now_unix)

      assert {:error, :invalid_datetime} = compare(before_datetime, earlier, "not a datetime")
    end

    test "after" do
      after_datetime = 19
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -1, :second)
      later = DateTime.add(now, 1, :second)
      {:ok, now_unix} = UserComparator.to_unix_seconds(now)
      {:ok, later_unix} = UserComparator.to_unix_seconds(later)

      assert {:ok, true} = compare(after_datetime, later, now_unix)
      assert {:ok, true} = compare(after_datetime, later_unix, now_unix)
      assert {:ok, true} = compare(after_datetime, to_string(later_unix), now_unix)
      assert {:ok, true} = compare(after_datetime, later, to_string(now_unix))
      assert {:ok, false} = compare(after_datetime, now, now_unix)
      assert {:ok, false} = compare(after_datetime, earlier, now_unix)
      assert {:ok, false} = compare(after_datetime, DateTime.to_naive(earlier), now_unix)

      assert {:error, :invalid_datetime} =
               compare(after_datetime, "not a datetime", now_unix)

      assert {:error, :invalid_datetime} = compare(after_datetime, later, "not a datetime")
    end
  end

  defp compare(comparator, user_value, comparison_value) do
    condition =
      UserCondition.new(comparator: comparator, comparison_attribute: "SomeAttribute", comparison_value: comparison_value)

    context = %ComparisonContext{
      condition: condition,
      context_salt: @context_salt,
      key: "someKey",
      salt: @salt
    }

    UserComparator.compare(comparator, user_value, comparison_value, context)
  end
end
