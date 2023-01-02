# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AnnouncementView do
  use Pleroma.Web, :view

  def render("index.json", %{announcements: announcements}) do
    render_many(announcements, __MODULE__, "show.json")
  end

  def render("show.json", %{announcement: announcement}) do
    Pleroma.Announcement.render_json(announcement, admin: true)
  end
end
