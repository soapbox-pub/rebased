# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SubchainPolicy do
  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF

  require Logger

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp lookup_subchain(actor) do
    with matches <- Config.get([:mrf_subchain, :match_actor]),
         {match, subchain} <- Enum.find(matches, fn {k, _v} -> String.match?(actor, k) end) do
      {:ok, match, subchain}
    else
      _e -> {:error, :notfound}
    end
  end

  @impl true
  def filter(%{"actor" => actor} = message) do
    with {:ok, match, subchain} <- lookup_subchain(actor) do
      Logger.debug(
        "[SubchainPolicy] Matched #{actor} against #{inspect(match)} with subchain #{inspect(subchain)}"
      )

      MRF.filter(subchain, message)
    else
      _e -> {:ok, message}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_subchain,
      related_policy: "Pleroma.Web.ActivityPub.MRF.SubchainPolicy",
      label: "MRF Subchain",
      description:
        "This policy processes messages through an alternate pipeline when a given message matches certain criteria." <>
          " All criteria are configured as a map of regular expressions to lists of policy modules.",
      children: [
        %{
          key: :match_actor,
          type: {:map, {:list, :string}},
          description: "Matches a series of regular expressions against the actor field",
          suggestions: [
            %{
              ~r/https:\/\/example.com/s => [Pleroma.Web.ActivityPub.MRF.DropPolicy]
            }
          ]
        }
      ]
    }
  end
end
