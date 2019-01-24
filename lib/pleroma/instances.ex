defmodule Pleroma.Instances do
  @moduledoc "Instances context."

  @adapter Pleroma.Instances.Instance

  defdelegate filter_reachable(urls), to: @adapter
  defdelegate reachable?(url), to: @adapter
  defdelegate set_reachable(url), to: @adapter
  defdelegate set_unreachable(url, unreachable_since \\ nil), to: @adapter

  def reachability_time_threshold,
    do: NaiveDateTime.add(NaiveDateTime.utc_now(), -30 * 24 * 3600, :second)

  def host(url_or_host) when is_binary(url_or_host) do
    if url_or_host =~ ~r/^http/i do
      URI.parse(url_or_host).host
    else
      url_or_host
    end
  end
end
