# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(%{"type" => "Create"} = object) do
    delist_threshold = Pleroma.Config.get([:mrf_hellthread, :delist_threshold])
    reject_threshold = Pleroma.Config.get([:mrf_hellthread, :reject_threshold])
    recipients = (object["to"] || []) ++ (object["cc"] || [])

    cond do
      length(recipients) > reject_threshold ->
        {:reject, nil}

      length(recipients) > delist_threshold ->
        if Enum.member?(object["to"], "https://www.w3.org/ns/activitystreams#Public") or
             Enum.member?(object["cc"], "https://www.w3.org/ns/activitystreams#Public") do
          object
          |> Kernel.update_in(["object", "to"], [
            User.get_cached_by_ap_id(object["actor"].follower_address)
          ])
          |> Kernel.update_in(["object", "cc"], ["https://www.w3.org/ns/activitystreams#Public"])
          |> Kernel.update_in(["to"], [
            User.get_cached_by_ap_id(object["actor"].follower_address)
          ])
          |> Kernel.update_in(["cc"], ["https://www.w3.org/ns/activitystreams#Public"])
        else
          {:ok, object}
        end

      true ->
        {:ok, object}
    end
  end

  @impl true
  def filter(object), do: {:ok, object}
end
