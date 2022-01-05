# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MigrationHelper.ObjectIdTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.MigrationHelper.ObjectId

  test "flake_from_time/1" do
    now = NaiveDateTime.utc_now()
    id = ObjectId.flake_from_time(now)

    assert FlakeId.flake_id?(id)
  end
end
