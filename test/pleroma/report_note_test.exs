# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReportNoteTest do
  alias Pleroma.ReportNote
  use Pleroma.DataCase, async: true
  import Pleroma.Factory

  test "create/3" do
    user = insert(:user)
    report = insert(:report_activity)
    assert {:ok, note} = ReportNote.create(user.id, report.id, "naughty boy")
    assert note.content == "naughty boy"
  end
end
