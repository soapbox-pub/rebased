defmodule Pleroma.Instances do
  @moduledoc "Instances context."

  @adapter Pleroma.Instances.Instance

  defdelegate filter_reachable(urls), to: @adapter
  defdelegate reachable?(url), to: @adapter
  defdelegate set_reachable(url), to: @adapter
  defdelegate set_unreachable(url, unreachable_since \\ nil), to: @adapter

  def reachability_datetime_threshold do
    federation_reachability_timeout_days =
      Pleroma.Config.get(:instance)[:federation_reachability_timeout_days] || 90

    if federation_reachability_timeout_days > 0 do
      NaiveDateTime.add(
        NaiveDateTime.utc_now(),
        -federation_reachability_timeout_days * 24 * 3600,
        :second
      )
    else
      ~N[0000-01-01 00:00:00]
    end
  end

  def host(url_or_host) when is_binary(url_or_host) do
    if url_or_host =~ ~r/^http/i do
      URI.parse(url_or_host).host
    else
      url_or_host
    end
  end
end
