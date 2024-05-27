# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ModerationLogView do
  use Pleroma.Web, :view

  alias Pleroma.ModerationLog

  def render("index.json", %{log: log}) do
    %{
      items: render_many(log.items, __MODULE__, "show.json", as: :log_entry),
      total: log.count
    }
  end

  def render("show.json", %{log_entry: log_entry}) do
    time =
      log_entry.inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    %{
      id: log_entry.id,
      data: log_entry.data,
      time: time,
      message: ModerationLog.get_log_entry_message(log_entry)
    }
  end
end
