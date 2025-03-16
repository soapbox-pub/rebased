# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.BackupViewTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.User.Backup
  alias Pleroma.Web.PleromaAPI.BackupView

  import Mox
  import Pleroma.Factory

  setup do
    ConfigMock
    |> stub_with(Pleroma.Test.StaticConfig)

    :ok
  end

  test "it renders the ID" do
    user = insert(:user)
    backup = Backup.new(user)

    result = BackupView.render("show.json", backup: backup)
    assert result.id == backup.id
  end

  test "it renders the processed state" do
    user = insert(:user)
    backup = Backup.new(user)

    result = BackupView.render("show.json", backup: backup)
    refute result.processed
  end
end
