defmodule Pleroma.DateTime.Impl do
  @behaviour Pleroma.DateTime

  @impl true
  def utc_now, do: NaiveDateTime.utc_now()
end
