# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventView do
  use Pleroma.Web, :view

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView

  def render(
        "participation_requests.json",
        %{activities: activities} = opts
      ) do
    render_many(
      activities,
      __MODULE__,
      "participation_request.json",
      Map.delete(opts, :activities)
    )
  end

  def render(
        "participation_request.json",
        %{activity: activity} = opts
      ) do
    user = CommonAPI.get_user(activity.data["actor"])

    %{
      account:
        AccountView.render("show.json", %{
          user: user,
          for: opts[:for]
        }),
      participation_message: activity.data["participationMessage"]
    }
  end
end
