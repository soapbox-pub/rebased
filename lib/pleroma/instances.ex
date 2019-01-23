defmodule Pleroma.Instances do
  @moduledoc "Instances context."

  @adapter Pleroma.Instances.Instance

  defdelegate reachable?(url), to: @adapter
  defdelegate set_reachable(url), to: @adapter
  defdelegate set_unreachable(url, unreachable_since \\ nil), to: @adapter

  def reachability_time_threshold,
    do: NaiveDateTime.add(NaiveDateTime.utc_now(), -30 * 24 * 3600, :second)
end
