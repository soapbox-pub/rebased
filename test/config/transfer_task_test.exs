# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTaskTest do
  use Pleroma.DataCase

  alias Pleroma.Web.AdminAPI.Config

  clear_config([:instance, :dynamic_configuration]) do
    Pleroma.Config.put([:instance, :dynamic_configuration], true)
  end

  test "transfer config values from db to env" do
    refute Application.get_env(:pleroma, :test_key)
    refute Application.get_env(:idna, :test_key)
    refute Application.get_env(:quack, :test_key)

    Config.create(%{
      group: ":pleroma",
      key: ":test_key",
      value: [live: 2, com: 3]
    })

    Config.create(%{
      group: ":idna",
      key: ":test_key",
      value: [live: 15, com: 35]
    })

    Config.create(%{
      group: ":quack",
      key: ":test_key",
      value: [:test_value1, :test_value2]
    })

    Pleroma.Config.TransferTask.start_link([])

    assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]
    assert Application.get_env(:idna, :test_key) == [live: 15, com: 35]
    assert Application.get_env(:quack, :test_key) == [:test_value1, :test_value2]

    on_exit(fn ->
      Application.delete_env(:pleroma, :test_key)
      Application.delete_env(:idna, :test_key)
      Application.delete_env(:quack, :test_key)
    end)
  end

  test "non existing atom" do
    Config.create(%{
      group: ":pleroma",
      key: ":undefined_atom_key",
      value: [live: 2, com: 3]
    })

    assert ExUnit.CaptureLog.capture_log(fn ->
             Pleroma.Config.TransferTask.start_link([])
           end) =~
             "updating env causes error, key: \":undefined_atom_key\", error: %ArgumentError{message: \"argument error\"}"
  end
end
