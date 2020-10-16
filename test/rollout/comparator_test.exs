defmodule ConfigCat.Rollout.ComparatorTest do
  @moduledoc """
  All evaluators are tested exhaustively in ConfigCat.RolloutTest,
  these are basic tests to ensure that we're using the correct
  comparator type for the given comparator value.
  """

  use ExUnit.Case, async: true

  alias ConfigCat.Rollout.Comparator
  alias Version.InvalidVersionError

  test "returns false if given an unknown comparator" do
    assert {:ok, false} = Comparator.compare(-1, "b", "a, b, c")
  end

  describe "basic comparators" do
    test "is_one_of" do
      is_one_of = 0

      assert {:ok, true} = Comparator.compare(is_one_of, "b", "a, b, c")
      assert {:ok, false} = Comparator.compare(is_one_of, "x", "a, b, c")
    end

    test "is_not_one_of" do
      is_not_one_of = 1

      assert {:ok, false} = Comparator.compare(is_not_one_of, "b", "a, b, c")
      assert {:ok, true} = Comparator.compare(is_not_one_of, "x", "a, b, c")
    end

    test "contains" do
      contains = 2

      assert {:ok, true} = Comparator.compare(contains, "jane@influxdata.com", "influxdata.com")
      assert {:ok, false} = Comparator.compare(contains, "jane@email.com", "influxdata.com")
    end

    test "does_not_contain" do
      does_not_contain = 3

      assert {:ok, false} =
               Comparator.compare(does_not_contain, "jane@influxdata.com", "influxdata.com")

      assert {:ok, true} =
               Comparator.compare(does_not_contain, "jane@email.com", "influxdata.com")
    end
  end

  describe "semantic version comparators" do
    test "is_one_of (semver)" do
      is_one_of_semver = 4

      assert {:ok, true} = Comparator.compare(is_one_of_semver, "1.2.0", "1.2.0, 1.3.4")
      assert {:ok, false} = Comparator.compare(is_one_of_semver, "2.0.0", "1.2.0, 1.3.4")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(is_one_of_semver, "invalid", "1.2.0, 1.3.4")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(is_one_of_semver, "1.2.0", "invalid, 1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(is_one_of_semver, "1.2.0", "1.2.0, invalid")
    end

    test "is_not_one_of (semver)" do
      is_not_one_of_semver = 5

      assert {:ok, true} = Comparator.compare(is_not_one_of_semver, "2.0.0", "1.2.0, 1.3.4")
      assert {:ok, false} = Comparator.compare(is_not_one_of_semver, "1.2.0", "1.2.0, 1.3.4")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(is_not_one_of_semver, "invalid", "1.2.0, 1.3.4")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(is_not_one_of_semver, "1.2.0", "invalid, 1.3.4")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(is_not_one_of_semver, "1.2.0", "1.2.0, invalid")
    end

    test "< (SemVer)" do
      less_than_semver = 6

      assert {:ok, true} = Comparator.compare(less_than_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = Comparator.compare(less_than_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = Comparator.compare(less_than_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(less_than_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(less_than_semver, "1.3.0", "invalid")
    end

    test "<= (SemVer)" do
      less_than_equal_semver = 7

      assert {:ok, true} = Comparator.compare(less_than_equal_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = Comparator.compare(less_than_equal_semver, "1.3.0", "1.2.0")
      assert {:ok, true} = Comparator.compare(less_than_equal_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(less_than_equal_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(less_than_equal_semver, "1.3.0", "invalid")
    end

    test "> (SemVer)" do
      greater_than_semver = 8

      assert {:ok, true} = Comparator.compare(greater_than_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = Comparator.compare(greater_than_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = Comparator.compare(greater_than_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(greater_than_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(greater_than_semver, "1.3.0", "invalid")
    end

    test ">= (SemVer)" do
      greater_than_equal_semver = 9

      assert {:ok, true} = Comparator.compare(greater_than_equal_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = Comparator.compare(greater_than_equal_semver, "1.2.0", "1.3.0")
      assert {:ok, true} = Comparator.compare(greater_than_equal_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(greater_than_equal_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               Comparator.compare(greater_than_equal_semver, "1.3.0", "invalid")
    end
  end

  describe "numeric comparators" do
    test "= (Number)" do
      equals_number = 10

      assert {:ok, true} = Comparator.compare(equals_number, "3.5", "3.5000")
      assert {:ok, true} = Comparator.compare(equals_number, "3,5", "3.5000")
      assert {:ok, true} = Comparator.compare(equals_number, 3.5, 3.5000)
      assert {:ok, false} = Comparator.compare(equals_number, "3,5", "4.752")
      assert {:error, :invalid_float} = Comparator.compare(equals_number, "not a float", "3.5000")
      assert {:error, :invalid_float} = Comparator.compare(equals_number, "3,5", "not a float")
    end

    test "<> (Number)" do
      not_equals_number = 11

      assert {:ok, false} = Comparator.compare(not_equals_number, "3.5", "3.5000")
      assert {:ok, false} = Comparator.compare(not_equals_number, "3,5", "3.5000")
      assert {:ok, false} = Comparator.compare(not_equals_number, 3.5, 3.5000)
      assert {:ok, true} = Comparator.compare(not_equals_number, "3,5", "4.752")

      assert {:error, :invalid_float} =
               Comparator.compare(not_equals_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               Comparator.compare(not_equals_number, "3,5", "not a float")
    end

    test "< (Number)" do
      less_than_number = 12

      assert {:ok, true} = Comparator.compare(less_than_number, "3.5", "3.6000")
      assert {:ok, true} = Comparator.compare(less_than_number, "3,5", "3.6000")
      assert {:ok, true} = Comparator.compare(less_than_number, 3.5, 3.6000)
      assert {:ok, false} = Comparator.compare(less_than_number, "3,5", "1.752")
      assert {:ok, false} = Comparator.compare(less_than_number, "3,5", "3.5")

      assert {:error, :invalid_float} =
               Comparator.compare(less_than_number, "not a float", "3.5000")

      assert {:error, :invalid_float} = Comparator.compare(less_than_number, "3,5", "not a float")
    end

    test "<= (Number)" do
      less_than_equal_number = 13

      assert {:ok, true} = Comparator.compare(less_than_equal_number, "3.5", "3.6000")
      assert {:ok, true} = Comparator.compare(less_than_equal_number, "3,5", "3.6000")
      assert {:ok, true} = Comparator.compare(less_than_equal_number, 3.5, 3.6000)
      assert {:ok, true} = Comparator.compare(less_than_equal_number, "3,5", "3.5")
      assert {:ok, false} = Comparator.compare(less_than_equal_number, "3,5", "1.752")

      assert {:error, :invalid_float} =
               Comparator.compare(less_than_equal_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               Comparator.compare(less_than_equal_number, "3,5", "not a float")
    end

    test "> (Number)" do
      greater_than_number = 14

      assert {:ok, false} = Comparator.compare(greater_than_number, "3.5", "3.6000")
      assert {:ok, false} = Comparator.compare(greater_than_number, "3,5", "3.6000")
      assert {:ok, false} = Comparator.compare(greater_than_number, 3.5, 3.6000)
      assert {:ok, false} = Comparator.compare(greater_than_number, "3,5", "3.5")
      assert {:ok, true} = Comparator.compare(greater_than_number, "3,5", "1.752")

      assert {:error, :invalid_float} =
               Comparator.compare(greater_than_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               Comparator.compare(greater_than_number, "3,5", "not a float")
    end

    test ">= (Number)" do
      greater_than_equal_number = 15

      assert {:ok, false} = Comparator.compare(greater_than_equal_number, "3.5", "3.6000")
      assert {:ok, false} = Comparator.compare(greater_than_equal_number, "3,5", "3.6000")
      assert {:ok, false} = Comparator.compare(greater_than_equal_number, 3.5, 3.6000)
      assert {:ok, true} = Comparator.compare(greater_than_equal_number, "3,5", "1.752")
      assert {:ok, true} = Comparator.compare(greater_than_equal_number, "3,5", "3.5")

      assert {:error, :invalid_float} =
               Comparator.compare(greater_than_equal_number, "not a float", "3.5000")

      assert {:error, :invalid_float} =
               Comparator.compare(greater_than_equal_number, "3,5", "not a float")
    end
  end

  describe "sensitive comparators" do
    setup do
      hashed = %{
        a: "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8",
        b: "e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98",
        c: "84a516841ba77a5b4648de2cd0dfcb30ea46dbb4"
      }

      {:ok, hashed: hashed}
    end

    test "is_one_of (sensitive)", %{hashed: hashed} do
      is_one_of_sensitive = 16
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = Comparator.compare(is_one_of_sensitive, "a", "#{a}, #{b}, #{c}")
      assert {:ok, false} = Comparator.compare(is_one_of_sensitive, "x", "#{a}, #{b}, #{c}")
    end

    test "is_not_one_of (sensitive)", %{hashed: hashed} do
      is_not_one_of_sensitive = 17
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = Comparator.compare(is_not_one_of_sensitive, "x", "#{a}, #{b}, #{c}")
      assert {:ok, false} = Comparator.compare(is_not_one_of_sensitive, "a", "#{a}, #{b}, #{c}")
    end
  end
end
