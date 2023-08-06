defmodule ConfigCat.FetchTime do
  @moduledoc false

  @type t :: non_neg_integer()

  @spec now_ms :: t()
  def now_ms, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)

  @spec to_datetime(t()) :: {:ok, DateTime.t()} | {:error, atom()}
  def to_datetime(ms) do
    DateTime.from_unix(ms, :millisecond)
  end
end
