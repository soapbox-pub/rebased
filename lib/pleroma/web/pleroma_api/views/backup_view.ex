# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.BackupView do
  use Pleroma.Web, :view

  alias Pleroma.User.Backup
  alias Pleroma.Web.CommonAPI.Utils

  def render("show.json", %{backup: %Backup{} = backup}) do
    %{
      id: backup.id,
      content_type: backup.content_type,
      url: download_url(backup),
      file_size: backup.file_size,
      processed: backup.processed,
      inserted_at: Utils.to_masto_date(backup.inserted_at)
    }
  end

  def render("index.json", %{backups: backups}) do
    render_many(backups, __MODULE__, "show.json")
  end

  def download_url(%Backup{file_name: file_name}) do
    Pleroma.Upload.base_url() <> "/backups/" <> file_name
  end
end
