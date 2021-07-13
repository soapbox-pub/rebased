# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

alias Pleroma.Activity
alias Pleroma.Group
alias Pleroma.Object
alias Pleroma.Pagination
alias Pleroma.Repo
alias Pleroma.Web.ActivityPub.ActivityPub

defmodule Pleroma.Group.Timeline do
  def fetch_group_activities(%Group{} = group, opts \\ %{}, pagination \\ :keyset) do
    opts =
      Map.merge(opts, %{
        actor_id: group.ap_id,
        type: "Announce"
      })

    [group.members_collection]
    |> ActivityPub.fetch_activities_query(opts)
    |> fetch_paginated_optimized(opts, pagination)
    |> Enum.map(&Object.normalize(&1, fetch: false).data["id"])
    |> Activity.create_by_object_ap_id()
    |> Activity.with_preloaded_object(:left)
    |> Repo.all()
  end

  defp fetch_paginated_optimized(query, opts, pagination) do
    # Note: tag-filtering funcs may apply "ORDER BY objects.id DESC",
    #   and extra sorting on "activities.id DESC NULLS LAST" would worse the query plan
    opts = Map.put(opts, :skip_extra_order, true)

    Pagination.fetch_paginated(query, opts, pagination)
  end
end
