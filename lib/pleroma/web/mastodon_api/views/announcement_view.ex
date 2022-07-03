# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AnnouncementView do
  use Pleroma.Web, :view

  def render("index.json", %{announcements: announcements, user: user}) do
    render_many(announcements, __MODULE__, "show.json", user: user)
  end

  def render("show.json", %{announcement: announcement, user: user}) do
    Pleroma.Announcement.render_json(announcement, for: user)
  end
end
