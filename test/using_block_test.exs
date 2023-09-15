defmodule ConfigCat.UsingBlockTest do
  use ExUnit.Case, async: true

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
