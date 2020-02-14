# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SubchainPolicy do
  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF

  require Logger

  @behaviour Pleroma.Web.ActivityPub.MRF

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
        "[SubchainPolicy] Matched #{actor} against #{inspect(match)} with subchain #{
          inspect(subchain)
        }"
      )

      subchain
      |> MRF.filter(message)
    else
      _e -> {:ok, message}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}
end
