# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerView do
  use Pleroma.Web, :view

  def render("markers.json", %{markers: markers}) do
    Enum.reduce(markers, %{}, fn m, acc ->
      Map.put_new(acc, m.timeline, %{
        last_read_id: m.last_read_id,
        version: m.lock_version,
        updated_at: NaiveDateTime.to_iso8601(m.updated_at)
      })
    end)
  end
end
