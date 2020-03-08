# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ReportView do
  use Pleroma.Web, :view

  def render("show.json", %{activity: activity}) do
    %{
      id: to_string(activity.id),
      action_taken: false
    }
  end
end
