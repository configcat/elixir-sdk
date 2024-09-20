defmodule ConfigCat.UsingBlockTest do
  # Must be async: false to avoid a collision with the integration tests.
  # Now that we only allow a single ConfigCat instance to use the same SDK key,
  # one of the async tests would fail due to the existing running instance.
  use ConfigCat.Case, async: false

  # defmodule CustomModule do
  #   @moduledoc false
  #   use ConfigCat, sdk_key: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/1cGEJXUwYUGZCBOL-E2sOw"
  # end

  test "can call API through using block" do
    # _pid = start_supervised!(CustomModule)

    # :ok = CustomModule.force_refresh()

    # assert CustomModule.get_value("keySampleText", "default value") ==
    #          "This text came from ConfigCat"
  end
end
