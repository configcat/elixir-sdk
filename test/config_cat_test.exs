defmodule ConfigCatTest do
  use ExUnit.Case
  doctest ConfigCat

  test "greets the world" do
    assert ConfigCat.hello() == :world
  end
end
