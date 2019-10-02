# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ScheduledActivityView do
  use Pleroma.Web, :view

  alias Pleroma.ScheduledActivity
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("index.json", %{scheduled_activities: scheduled_activities}) do
    render_many(scheduled_activities, __MODULE__, "show.json")
  end

  def render("show.json", %{scheduled_activity: %ScheduledActivity{} = scheduled_activity}) do
    %{
      id: to_string(scheduled_activity.id),
      scheduled_at: CommonAPI.Utils.to_masto_date(scheduled_activity.scheduled_at),
      params: status_params(scheduled_activity.params)
    }
    |> with_media_attachments(scheduled_activity)
  end

  defp with_media_attachments(data, %{params: %{"media_attachments" => media_attachments}}) do
    attachments = render_many(media_attachments, StatusView, "attachment.json", as: :attachment)
    Map.put(data, :media_attachments, attachments)
  end

  defp with_media_attachments(data, _), do: data

  defp status_params(params) do
    data = %{
      text: params["status"],
      sensitive: params["sensitive"],
      spoiler_text: params["spoiler_text"],
      visibility: params["visibility"],
      scheduled_at: params["scheduled_at"],
      poll: params["poll"],
      in_reply_to_id: params["in_reply_to_id"]
    }

    case params["media_ids"] do
      nil -> data
      media_ids -> Map.put(data, :media_ids, media_ids)
    end
  end
end
