# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.EctoTest do
  use ExUnit.Case, async: true

  test "raise on bad path" do
    assert_raise RuntimeError, ~r/Could not find migrations directory/, fn ->
      Mix.Tasks.Pleroma.Ecto.ensure_migrations_path(Pleroma.Repo,
        migrations_path: "some-path"
      )
    end
  end
end
