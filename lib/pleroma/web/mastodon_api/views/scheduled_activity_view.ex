# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ScheduledActivityView do
  use Pleroma.Web, :view

  alias Pleroma.ScheduledActivity
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.ScheduledActivityView

  def render("index.json", %{scheduled_activities: scheduled_activities}) do
    render_many(scheduled_activities, ScheduledActivityView, "show.json")
  end

  def render("show.json", %{scheduled_activity: %ScheduledActivity{} = scheduled_activity}) do
    %{
      id: scheduled_activity.id |> to_string,
      scheduled_at: scheduled_activity.scheduled_at |> CommonAPI.Utils.to_masto_date(),
      params: scheduled_activity.params
    }
  end
end
