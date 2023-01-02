# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTaskTest do
  use Pleroma.DataCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  alias Pleroma.Config.TransferTask

  setup do: clear_config(:configurable_from_database, true)

  test "transfer config values from db to env" do
    refute Application.get_env(:pleroma, :test_key)
    refute Application.get_env(:idna, :test_key)
    refute Application.get_env(:postgrex, :test_key)
    initial = Application.get_env(:logger, :level)

    insert(:config, key: :test_key, value: [live: 2, com: 3])
    insert(:config, group: :idna, key: :test_key, value: [live: 15, com: 35])
    insert(:config, group: :postgrex, key: :test_key, value: :value)
    insert(:config, group: :logger, key: :level, value: :debug)

    TransferTask.start_link([])

    assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]
    assert Application.get_env(:idna, :test_key) == [live: 15, com: 35]
    assert Application.get_env(:logger, :level) == :debug
    assert Application.get_env(:postgrex, :test_key) == :value

    on_exit(fn ->
      Application.delete_env(:pleroma, :test_key)
      Application.delete_env(:idna, :test_key)
      Application.delete_env(:postgrex, :test_key)
      Application.put_env(:logger, :level, initial)
    end)
  end

  test "transfer config values for 1 group and some keys" do
    level = Application.get_env(:somegroup, :level)
    meta = Application.get_env(:somegroup, :meta)

    insert(:config, group: :somegroup, key: :level, value: :info)
    insert(:config, group: :somegroup, key: :meta, value: [:none])

    TransferTask.start_link([])

    assert Application.get_env(:somegroup, :level) == :info
    assert Application.get_env(:somegroup, :meta) == [:none]

    on_exit(fn ->
      Application.put_env(:somegroup, :level, level)
      Application.put_env(:somegroup, :meta, meta)
    end)
  end

  test "transfer config values with full subkey update" do
    clear_config(:emoji)
    clear_config(:assets)

    insert(:config, key: :emoji, value: [groups: [a: 1, b: 2]])
    insert(:config, key: :assets, value: [mascots: [a: 1, b: 2]])

    TransferTask.start_link([])

    emoji_env = Application.get_env(:pleroma, :emoji)
    assert emoji_env[:groups] == [a: 1, b: 2]
    assets_env = Application.get_env(:pleroma, :assets)
    assert assets_env[:mascots] == [a: 1, b: 2]
  end

  describe "pleroma restart" do
    setup do
      on_exit(fn ->
        Restarter.Pleroma.refresh()

        # Restarter.Pleroma.refresh/0 is an asynchronous call.
        # A GenServer will first finish the previous call before starting a new one.
        # Here we do a synchronous call.
        # That way we are sure that the previous call has finished before we continue.
        # See https://stackoverflow.com/questions/51361856/how-to-use-task-await-with-genserver
        Restarter.Pleroma.rebooted?()
      end)
    end

    test "don't restart if no reboot time settings were changed" do
      clear_config(:emoji)
      insert(:config, key: :emoji, value: [groups: [a: 1, b: 2]])

      refute String.contains?(
               capture_log(fn ->
                 TransferTask.start_link([])

                 # TransferTask.start_link/1 is an asynchronous call.
                 # A GenServer will first finish the previous call before starting a new one.
                 # Here we do a synchronous call.
                 # That way we are sure that the previous call has finished before we continue.
                 Restarter.Pleroma.rebooted?()
               end),
               "pleroma restarted"
             )
    end

    test "on reboot time key" do
      clear_config(:shout)
      insert(:config, key: :shout, value: [enabled: false])

      # Note that we don't actually restart Pleroma.
      # See module Restarter.Pleroma
      assert capture_log(fn ->
               TransferTask.start_link([])

               # TransferTask.start_link/1 is an asynchronous call.
               # A GenServer will first finish the previous call before starting a new one.
               # Here we do a synchronous call.
               # That way we are sure that the previous call has finished before we continue.
               Restarter.Pleroma.rebooted?()
             end) =~ "pleroma restarted"
    end

    test "on reboot time subkey" do
      clear_config(Pleroma.Captcha)
      insert(:config, key: Pleroma.Captcha, value: [seconds_valid: 60])

      # Note that we don't actually restart Pleroma.
      # See module Restarter.Pleroma
      assert capture_log(fn ->
               TransferTask.start_link([])

               # TransferTask.start_link/1 is an asynchronous call.
               # A GenServer will first finish the previous call before starting a new one.
               # Here we do a synchronous call.
               # That way we are sure that the previous call has finished before we continue.
               Restarter.Pleroma.rebooted?()
             end) =~ "pleroma restarted"
    end

    test "don't restart pleroma on reboot time key and subkey if there is false flag" do
      clear_config(:shout)
      clear_config(Pleroma.Captcha)

      insert(:config, key: :shout, value: [enabled: false])
      insert(:config, key: Pleroma.Captcha, value: [seconds_valid: 60])

      refute String.contains?(
               capture_log(fn ->
                 TransferTask.load_and_update_env([], false)

                 # TransferTask.start_link/1 is an asynchronous call.
                 # A GenServer will first finish the previous call before starting a new one.
                 # Here we do a synchronous call.
                 # That way we are sure that the previous call has finished before we continue.
                 Restarter.Pleroma.rebooted?()
               end),
               "pleroma restarted"
             )
    end
  end
end
