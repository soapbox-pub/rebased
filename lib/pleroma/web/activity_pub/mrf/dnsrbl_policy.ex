# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.DNSRBLPolicy do
  @moduledoc """
  Dynamic activity filtering based on an RBL database

  This MRF makes queries to a custom DNS server which will
  respond with values indicating the classification of the domain
  the activity originated from. This method has been widely used
  in the email anti-spam industry for very fast reputation checks.

  e.g., if the DNS response is 127.0.0.1 or empty, the domain is OK
  Other values such as 127.0.0.2 may be used for specific classifications.

  Information for why the host is blocked can be stored in a corresponding TXT record.

  This method is fail-open so if the queries fail the activites are accepted.

  An example of software meant for this purpsoe is rbldnsd which can be found
  at http://www.corpit.ru/mjt/rbldnsd.html or mirrored at
  https://git.pleroma.social/feld/rbldnsd

  It is highly recommended that you run your own copy of rbldnsd and use an
  external mechanism to sync/share the contents of the zone file. This is
  important to keep the latency on the queries as low as possible and prevent
  your DNS server from being attacked so it fails and content is permitted.
  """

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Config

  require Logger

  @query_retries 1
  @query_timeout 500

  @impl true
  def filter(%{"actor" => actor} = activity) do
    actor_info = URI.parse(actor)

    with {:ok, activity} <- check_rbl(actor_info, activity) do
      {:ok, activity}
    else
      _ -> {:reject, "[DNSRBLPolicy]"}
    end
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe do
    mrf_dnsrbl =
      Config.get(:mrf_dnsrbl)
      |> Enum.into(%{})

    {:ok, %{mrf_dnsrbl: mrf_dnsrbl}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_dnsrbl,
      related_policy: "Pleroma.Web.ActivityPub.MRF.DNSRBLPolicy",
      label: "MRF DNSRBL",
      description: "DNS RealTime Blackhole Policy",
      children: [
        %{
          key: :nameserver,
          type: {:string},
          description: "DNSRBL Nameserver to Query (IP or hostame)",
          suggestions: ["127.0.0.1"]
        },
        %{
          key: :port,
          type: {:string},
          description: "Nameserver port",
          suggestions: ["53"]
        },
        %{
          key: :zone,
          type: {:string},
          description: "Root zone for querying",
          suggestions: ["bl.pleroma.com"]
        }
      ]
    }
  end

  defp check_rbl(%{host: actor_host}, activity) do
    with false <- match?(^actor_host, Pleroma.Web.Endpoint.host()),
         zone when not is_nil(zone) <- Keyword.get(Config.get([:mrf_dnsrbl]), :zone) do
      query =
        Enum.join([actor_host, zone], ".")
        |> String.to_charlist()

      rbl_response = rblquery(query)

      if Enum.empty?(rbl_response) do
        {:ok, activity}
      else
        Task.start(fn ->
          reason =
            case rblquery(query, :txt) do
              [[result]] -> result
              _ -> "undefined"
            end

          Logger.warning(
            "DNSRBL Rejected activity from #{actor_host} for reason: #{inspect(reason)}"
          )
        end)

        :error
      end
    else
      _ -> {:ok, activity}
    end
  end

  defp get_rblhost_ip(rblhost) do
    case rblhost |> String.to_charlist() |> :inet_parse.address() do
      {:ok, _} -> rblhost |> String.to_charlist() |> :inet_parse.address()
      _ -> {:ok, rblhost |> String.to_charlist() |> :inet_res.lookup(:in, :a) |> Enum.random()}
    end
  end

  defp rblquery(query, type \\ :a) do
    config = Config.get([:mrf_dnsrbl])

    case get_rblhost_ip(config[:nameserver]) do
      {:ok, rblnsip} ->
        :inet_res.lookup(query, :in, type,
          nameservers: [{rblnsip, config[:port]}],
          timeout: @query_timeout,
          retry: @query_retries
        )

      _ ->
        []
    end
  end
end
