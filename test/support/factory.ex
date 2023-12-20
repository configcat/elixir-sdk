defmodule ConfigCat.Factory do
  @moduledoc false
  import Jason.Sigil

  alias ConfigCat.Config

  @spec config :: Config.t()
  def config do
    ~J"""
    {
      "p": {
        "u": "https://cdn-global.configcat.com",
        "r": 0
      },
      "s": [
        {"n": "id1", "r": [{"a": "Identifier", "c": 2, "l": ["@test1.com"]}]},
        {"n": "id2", "r": [{"a": "Identifier", "c": 2, "l": ["@test2.com"]}]}
      ],
      "f": {
        "testBoolKey": {"v": {"b": true}, "t": 0},
        "testStringKey": {"v": {"s": "testValue"}, "i": "id", "t": 1, "r": [
          {"c": [{"s": {"s": 0, "c": 0}}], "s": {"v": {"s": "fake1"}, "i": "id1"}},
          {"c": [{"s": {"s": 1, "c": 0}}], "s": {"v": {"s": "fake2"}, "i": "id2"}}
        ]},
        "testIntKey": {"v": {"i": 1}, "t": 2},
        "testDoubleKey": {"v": {"d": 1.1}, "t": 3},
        "key1": {"v": {"b": true}, "t": 0, "i": "fakeId1"},
        "key2": {"v": {"b": false}, "t": 0, "i": "fakeId2"}
      }
    }
    """
  end
end
