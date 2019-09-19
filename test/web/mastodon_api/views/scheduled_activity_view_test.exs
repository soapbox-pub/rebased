# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ScheduledActivityViewTest do
  use Pleroma.DataCase
  alias Pleroma.ScheduledActivity
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.ScheduledActivityView
  alias Pleroma.Web.MastodonAPI.StatusView
  import Pleroma.Factory

  test "A scheduled activity with a media attachment" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "hi"})

    scheduled_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(:timer.minutes(10), :millisecond)
      |> NaiveDateTime.to_iso8601()

    file = %Plug.Upload{
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

    attrs = %{
      params: %{
        "media_ids" => [upload.id],
        "status" => "hi",
        "sensitive" => true,
        "spoiler_text" => "spoiler",
        "visibility" => "unlisted",
        "in_reply_to_id" => to_string(activity.id)
      },
      scheduled_at: scheduled_at
    }

    {:ok, scheduled_activity} = ScheduledActivity.create(user, attrs)
    result = ScheduledActivityView.render("show.json", %{scheduled_activity: scheduled_activity})

    expected = %{
      id: to_string(scheduled_activity.id),
      media_attachments:
        %{"media_ids" => [upload.id]}
        |> Utils.attachments_from_ids()
        |> Enum.map(&StatusView.render("attachment.json", %{attachment: &1})),
      params: %{
        in_reply_to_id: to_string(activity.id),
        media_ids: [upload.id],
        poll: nil,
        scheduled_at: nil,
        sensitive: true,
        spoiler_text: "spoiler",
        text: "hi",
        visibility: "unlisted"
      },
      scheduled_at: Utils.to_masto_date(scheduled_activity.scheduled_at)
    }

    assert expected == result
  end
end
