defmodule Mix.Tasks.Pleroma.Ecto.RollbackTest do
  use Pleroma.DataCase
  import ExUnit.CaptureLog
  require Logger

  test "ecto.rollback info message" do
    level = Logger.level()
    Logger.configure(level: :warn)

    assert capture_log(fn ->
             Mix.Tasks.Pleroma.Ecto.Rollback.run()
           end) =~ "[info] Rollback succesfully"

    Logger.configure(level: level)
  end
end
