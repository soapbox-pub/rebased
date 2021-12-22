# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-onl

defmodule Mix.Tasks.Pleroma.Ecto.MigrateTest do
  use Pleroma.DataCase
  import ExUnit.CaptureLog
  require Logger

  test "ecto.migrate info message" do
    level = Logger.level()
    Logger.configure(level: :warn)

    assert capture_log(fn ->
             Mix.Tasks.Pleroma.Ecto.Migrate.run()
           end) =~ "[info] Migrations already up"

    Logger.configure(level: level)
  end
end
