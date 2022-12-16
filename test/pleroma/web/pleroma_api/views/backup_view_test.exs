# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.BackupViewTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.User.Backup
  alias Pleroma.Web.PleromaAPI.BackupView
  import Pleroma.Factory

  test "it renders the ID" do
    user = insert(:user)
    backup = Backup.new(user)

    result = BackupView.render("show.json", backup: backup)
    assert result.id == backup.id
  end

  test "it renders the state and processed_number" do
    user = insert(:user)
    backup = Backup.new(user)

    result = BackupView.render("show.json", backup: backup)
    assert result.state == to_string(backup.state)
    assert result.processed_number == backup.processed_number
  end

  test "it renders failed state with legacy records" do
    backup = %Backup{
      id: 0,
      content_type: "application/zip",
      file_name: "dummy",
      file_size: 1,
      state: :invalid,
      processed: true,
      processed_number: 1,
      inserted_at: NaiveDateTime.utc_now()
    }

    result = BackupView.render("show.json", backup: backup)
    assert result.state == "complete"

    backup = %Backup{
      id: 0,
      content_type: "application/zip",
      file_name: "dummy",
      file_size: 1,
      state: :invalid,
      processed: false,
      processed_number: 1,
      inserted_at: NaiveDateTime.utc_now()
    }

    result = BackupView.render("show.json", backup: backup)
    assert result.state == "failed"
  end
end
