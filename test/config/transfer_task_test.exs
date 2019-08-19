# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTaskTest do
  use Pleroma.DataCase

  clear_config([:instance, :dynamic_configuration]) do
    Pleroma.Config.put([:instance, :dynamic_configuration], true)
  end

  test "transfer config values from db to env" do
    refute Application.get_env(:pleroma, :test_key)
    refute Application.get_env(:idna, :test_key)

    Pleroma.Web.AdminAPI.Config.create(%{
      group: "pleroma",
      key: "test_key",
      value: [live: 2, com: 3]
    })

    Pleroma.Web.AdminAPI.Config.create(%{
      group: "idna",
      key: "test_key",
      value: [live: 15, com: 35]
    })

    Pleroma.Config.TransferTask.start_link([])

    assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]
    assert Application.get_env(:idna, :test_key) == [live: 15, com: 35]

    on_exit(fn ->
      Application.delete_env(:pleroma, :test_key)
      Application.delete_env(:idna, :test_key)
    end)
  end

  test "non existing atom" do
    Pleroma.Web.AdminAPI.Config.create(%{
      group: "pleroma",
      key: "undefined_atom_key",
      value: [live: 2, com: 3]
    })

    assert ExUnit.CaptureLog.capture_log(fn ->
             Pleroma.Config.TransferTask.start_link([])
           end) =~
             "updating env causes error, key: \"undefined_atom_key\", error: %ArgumentError{message: \"argument error\"}"
  end
end
