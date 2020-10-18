defmodule ConfigCat.FetchPolicy do
  defstruct [
    :type,
    cache_expiry_seconds: 0,
    poll_interval_seconds: 0
  ]

  def manual do
    %__MODULE__{type: :manual}
  end

  def lazy(cache_expiry_seconds: seconds) do
    %__MODULE__{type: :lazy, cache_expiry_seconds: seconds}
  end

  def auto(options \\ []) do
    seconds = options |> Keyword.get(:poll_interval_seconds, 60) |> max(1)

    %__MODULE__{
      type: :auto,
      poll_interval_seconds: seconds
    }
  end

  def mode(%__MODULE__{type: :auto}), do: "a"
  def mode(%__MODULE__{type: :lazy}), do: "l"
  def mode(%__MODULE__{type: :manual}), do: "m"

  def needs_fetch?(%__MODULE__{type: :lazy}, nil), do: true

  def needs_fetch?(
        %__MODULE__{type: :lazy, cache_expiry_seconds: expiry_seconds},
        last_update_time
      ) do
    cache_expired?(last_update_time, expiry_seconds)
  end

  def needs_fetch?(_policy, _last_update_time), do: false

  def schedule_initial_fetch?(%__MODULE__{type: :auto}), do: true
  def schedule_initial_fetch?(_policy), do: false

  def schedule_next_fetch(%__MODULE__{type: :auto, poll_interval_seconds: seconds}, pid) do
    Process.send_after(pid, :refresh, seconds * 1000)
  end

  def schedule_next_fetch(_policy, _pid), do: nil

  defp cache_expired?(last_update_time, expiry_seconds) do
    :gt !==
      last_update_time
      |> DateTime.add(expiry_seconds, :second)
      |> DateTime.compare(DateTime.utc_now())
  end
end
