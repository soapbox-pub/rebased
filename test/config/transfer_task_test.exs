defmodule Pleroma.Config.TransferTaskTest do
  use Pleroma.DataCase

  setup do
    dynamic = Pleroma.Config.get([:instance, :dynamic_configuration])

    Pleroma.Config.put([:instance, :dynamic_configuration], true)

    on_exit(fn ->
      Pleroma.Config.put([:instance, :dynamic_configuration], dynamic)
    end)
  end

  test "transfer config values from db to env" do
    refute Application.get_env(:pleroma, :test_key)
    Pleroma.Web.AdminAPI.Config.create(%{key: "test_key", value: [live: 2, com: 3]})

    Pleroma.Config.TransferTask.start_link()

    assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]

    on_exit(fn ->
      Application.delete_env(:pleroma, :test_key)
    end)
  end

  test "non existing atom" do
    Pleroma.Web.AdminAPI.Config.create(%{key: "undefined_atom_key", value: [live: 2, com: 3]})

    assert ExUnit.CaptureLog.capture_log(fn ->
             Pleroma.Config.TransferTask.start_link()
           end) =~
             "updating env causes error, key: \"undefined_atom_key\", error: %ArgumentError{message: \"argument error\"}"
  end
end
