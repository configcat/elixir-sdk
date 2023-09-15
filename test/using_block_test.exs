defmodule ConfigCat.UsingBlockTest do
  # Must be async: false to avoid a collision with the integration tests.
  # Now that we only allow a single ConfigCat instance to use the same SDK key,
  # one of the async tests would fail due to the existing running instance.
  use ExUnit.Case, async: false

  defmodule CustomModule do
    @moduledoc false
    use ConfigCat, sdk_key: "PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA"
  end

  test "can call API through using block" do
    _pid = start_supervised!(CustomModule)

    :ok = CustomModule.force_refresh()

    assert CustomModule.get_value("keySampleText", "default value") ==
             "This text came from ConfigCat"
  end
end
