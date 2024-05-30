# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.SchemaTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Repo

  test "No unindexed foreign keys" do
    query = File.read!("test/fixtures/unindexed_fk.sql")

    {:ok, result} = Repo.query(query)

    assert Enum.empty?(result.rows)
  end
end
