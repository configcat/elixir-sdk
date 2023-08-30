defmodule Multi do
  @moduledoc """
  A simple GenServer to run ConfigCat examples.

  The ConfigCat GenServer is started by our application supervisor in `simple/application.ex`.

  In the first ConfigCat config there is a 'keySampleText' setting with the following rules:
  1. If the User's country is Hungary, the value should be 'Dog'
  2. If the User's custom property - SubscriptionType - is unlimited, the value should be 'Lion'
  3. In other cases there is a percentage rollout configured with 50% 'Falcon' and 50% 'Horse' rules.
  4. There is also a default value configured: 'Cat'

  In the second ConfigCat config there are `isPOCFeatureEnabled` and `isAwesomeFeatureEnabled` settings.
  """

  use GenServer, restart: :transient

  alias ConfigCat.User

  defmodule First do
    @moduledoc false
    use ConfigCat, sdk_key: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A"
  end

  defmodule Second do
    @moduledoc false
    use ConfigCat, sdk_key: "PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ"
  end

  def start_link(_options) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl GenServer
  def init(_initial_state) do
    run_first_examples()
    run_second_examples()

    {:ok, %{}}
  end

  defp run_first_examples do
    # 1. As the passed User's country is Hungary this will print 'Dog'
    my_setting_value =
      First.get_value("keySampleText", "default value", User.new("key", country: "Hungary"))

    print("keySampleText", my_setting_value)

    # 2. As the passed User's custom attribute - SubscriptionType - is unlimited this will print 'Lion'
    my_setting_value =
      First.get_value(
        "keySampleText",
        "default value",
        User.new("key", custom: %{"SubscriptionType" => "unlimited"})
      )

    print("keySampleText", my_setting_value)

    # 3/a. As the passed User doesn't fill in any rules, this will serve 'Falcon' or 'Horse'.
    my_setting_value = First.get_value("keySampleText", "default value", User.new("key"))

    print("keySampleText", my_setting_value)

    # 3/b. As this is the same user from 3/a., this will print the same value as the previous one ('Falcon' or 'Horse')
    my_setting_value = First.get_value("keySampleText", "default value", User.new("key"))

    print("keySampleText", my_setting_value)

    # 4. As we don't pass an User object to this call, this will print the setting's default value - 'Cat'
    my_setting_value = First.get_value("keySampleText", "default value")
    print("keySampleText", my_setting_value)

    # 'myKeyNotExists' setting doesn't exist in the project configuration and the client returns default value ('default value')
    my_setting_value = First.get_value("myKeyNotExists", "default value")
    print("myKeyNotExists", my_setting_value)
  end

  def run_second_examples do
    user =
      User.new("Some UserID",
        email: "configcat@example.com",
        custom: %{version: "1.0.0"}
      )

    value = Second.get_value("isPOCFeatureEnabled", "default value", user)
    print("isPOCFeatureEnabled", value)

    value = Second.get_value("isAwesomeFeatureEnabled", "default value")
    print("isAwesomeFeatureEnabled", value)
  end

  defp print(key, value) do
    IO.puts("'#{key}' value from ConfigCat: #{value}")
  end
end
