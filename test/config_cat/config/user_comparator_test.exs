defmodule ConfigCat.Config.UserComparatorTest do
  @moduledoc """
  All evaluators are tested exhaustively in ConfigCat.RolloutTest.
  These are basic tests to ensure that we're using the correct
  comparator type for the given comparator value.
  """

  use ExUnit.Case, async: true

  alias ConfigCat.Config.UserComparator
  alias Version.InvalidVersionError

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

    test "contains" do
      contains = 2

      assert {:ok, true} = compare(contains, "jane@configcat.com", "configcat.com")
      assert {:ok, false} = compare(contains, "jane@email.com", "configcat.com")
    end

    test "does_not_contain" do
      does_not_contain = 3

      assert {:ok, false} =
               compare(does_not_contain, "jane@configcat.com", "configcat.com")

      assert {:ok, true} =
               compare(does_not_contain, "jane@email.com", "configcat.com")
    end
  end

  describe "semantic version comparators" do
    test "is_one_of (semver)" do
      is_one_of_semver = 4

      assert {:ok, true} = compare(is_one_of_semver, "1.2.0", ["1.2.0", "1.3.4"])
      assert {:ok, false} = compare(is_one_of_semver, "2.0.0", ["1.2.0", "1.3.4"])

      assert {:error, %InvalidVersionError{}} =
               compare(is_one_of_semver, "invalid", ["1.2.0", "1.3.4"])

      assert {:error, %InvalidVersionError{}} =
               compare(is_one_of_semver, "1.2.0", ["invalid", "1.2.0"])

      assert {:error, %InvalidVersionError{}} =
               compare(is_one_of_semver, "1.2.0", ["1.2.0", "invalid"])
    end

    test "is_not_one_of (semver)" do
      is_not_one_of_semver = 5

      assert {:ok, true} = compare(is_not_one_of_semver, "2.0.0", ["1.2.0", "1.3.4"])
      assert {:ok, false} = compare(is_not_one_of_semver, "1.2.0", ["1.2.0", "1.3.4"])

      assert {:error, %InvalidVersionError{}} =
               compare(is_not_one_of_semver, "invalid", ["1.2.0", "1.3.4"])

      assert {:error, %InvalidVersionError{}} =
               compare(is_not_one_of_semver, "1.2.0", ["invalid", "1.3.4"])

      assert {:error, %InvalidVersionError{}} =
               compare(is_not_one_of_semver, "1.2.0", ["1.2.0", "invalid"])
    end

    test "< (SemVer)" do
      less_than_semver = 6

      assert {:ok, true} = compare(less_than_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = compare(less_than_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = compare(less_than_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(less_than_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(less_than_semver, "1.3.0", "invalid")
    end

    test "<= (SemVer)" do
      less_than_equal_semver = 7

      assert {:ok, true} = compare(less_than_equal_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = compare(less_than_equal_semver, "1.3.0", "1.2.0")
      assert {:ok, true} = compare(less_than_equal_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(less_than_equal_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(less_than_equal_semver, "1.3.0", "invalid")
    end

    test "> (SemVer)" do
      greater_than_semver = 8

      assert {:ok, true} = compare(greater_than_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = compare(greater_than_semver, "1.2.0", "1.3.0")
      assert {:ok, false} = compare(greater_than_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(greater_than_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(greater_than_semver, "1.3.0", "invalid")
    end

    test ">= (SemVer)" do
      greater_than_equal_semver = 9

      assert {:ok, true} = compare(greater_than_equal_semver, "1.3.0", "1.2.0")
      assert {:ok, false} = compare(greater_than_equal_semver, "1.2.0", "1.3.0")
      assert {:ok, true} = compare(greater_than_equal_semver, "1.2.0", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
               compare(greater_than_equal_semver, "invalid", "1.2.0")

      assert {:error, %InvalidVersionError{}} =
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

  describe "sensitive comparators" do
    setup do
      hashed = %{
        a: "d21ec0ebb63930d047bb48e94674ea2ae07b8c0e7fec9de888f31bb22444be85",
        b: "6f816cafc2729b3f031874ba92e13f05f0b1d9dad3496cecfa2331940aca43be",
        c: "a5dbca52195f5eb637f760d9553f3e45088a447566c4067c9f73746a67b93429"
      }

      {:ok, hashed: hashed}
    end

    test "is_one_of (sensitive)", %{hashed: hashed} do
      is_one_of_sensitive = 16
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = compare(is_one_of_sensitive, "a", [a, b, c])
      assert {:ok, false} = compare(is_one_of_sensitive, "x", [a, b, c])
    end

    test "is_not_one_of (sensitive)", %{hashed: hashed} do
      is_not_one_of_sensitive = 17
      %{a: a, b: b, c: c} = hashed

      assert {:ok, true} = compare(is_not_one_of_sensitive, "x", [a, b, c])
      assert {:ok, false} = compare(is_not_one_of_sensitive, "a", [a, b, c])
    end
  end

  defp compare(comparator, user_value, comparison_value) do
    UserComparator.compare(comparator, user_value, comparison_value, @context_salt, @salt)
  end
end
