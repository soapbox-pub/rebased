# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTaskTest do
  use Pleroma.DataCase

  import ExUnit.CaptureLog

  alias Pleroma.Config.TransferTask
  alias Pleroma.ConfigDB

  clear_config(:configurable_from_database) do
    Pleroma.Config.put(:configurable_from_database, true)
  end

  test "transfer config values from db to env" do
    refute Application.get_env(:pleroma, :test_key)
    refute Application.get_env(:idna, :test_key)
    refute Application.get_env(:quack, :test_key)

    ConfigDB.create(%{
      group: ":pleroma",
      key: ":test_key",
      value: [live: 2, com: 3]
    })

    ConfigDB.create(%{
      group: ":idna",
      key: ":test_key",
      value: [live: 15, com: 35]
    })

    ConfigDB.create(%{
      group: ":quack",
      key: ":test_key",
      value: [:test_value1, :test_value2]
    })

    TransferTask.start_link([])

    assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]
    assert Application.get_env(:idna, :test_key) == [live: 15, com: 35]
    assert Application.get_env(:quack, :test_key) == [:test_value1, :test_value2]

    on_exit(fn ->
      Application.delete_env(:pleroma, :test_key)
      Application.delete_env(:idna, :test_key)
      Application.delete_env(:quack, :test_key)
    end)
  end

  test "transfer config values for 1 group and some keys" do
    level = Application.get_env(:quack, :level)
    meta = Application.get_env(:quack, :meta)

    ConfigDB.create(%{
      group: ":quack",
      key: ":level",
      value: :info
    })

    ConfigDB.create(%{
      group: ":quack",
      key: ":meta",
      value: [:none]
    })

    TransferTask.start_link([])

    assert Application.get_env(:quack, :level) == :info
    assert Application.get_env(:quack, :meta) == [:none]
    default = Pleroma.Config.Holder.config(:quack, :webhook_url)
    assert Application.get_env(:quack, :webhook_url) == default

    on_exit(fn ->
      Application.put_env(:quack, :level, level)
      Application.put_env(:quack, :meta, meta)
    end)
  end

  test "transfer config values with full subkey update" do
    emoji = Application.get_env(:pleroma, :emoji)
    assets = Application.get_env(:pleroma, :assets)

    ConfigDB.create(%{
      group: ":pleroma",
      key: ":emoji",
      value: [groups: [a: 1, b: 2]]
    })

    ConfigDB.create(%{
      group: ":pleroma",
      key: ":assets",
      value: [mascots: [a: 1, b: 2]]
    })

    TransferTask.start_link([])

    emoji_env = Application.get_env(:pleroma, :emoji)
    assert emoji_env[:groups] == [a: 1, b: 2]
    assets_env = Application.get_env(:pleroma, :assets)
    assert assets_env[:mascots] == [a: 1, b: 2]

    on_exit(fn ->
      Application.put_env(:pleroma, :emoji, emoji)
      Application.put_env(:pleroma, :assets, assets)
    end)
  end

  describe "pleroma restart" do
    setup do
      on_exit(fn -> Restarter.Pleroma.refresh() end)
    end

    test "don't restart if no reboot time settings were changed" do
      emoji = Application.get_env(:pleroma, :emoji)
      on_exit(fn -> Application.put_env(:pleroma, :emoji, emoji) end)

      ConfigDB.create(%{
        group: ":pleroma",
        key: ":emoji",
        value: [groups: [a: 1, b: 2]]
      })

      refute String.contains?(
               capture_log(fn -> TransferTask.start_link([]) end),
               "pleroma restarted"
             )
    end

    test "on reboot time key" do
      chat = Application.get_env(:pleroma, :chat)
      on_exit(fn -> Application.put_env(:pleroma, :chat, chat) end)

      ConfigDB.create(%{
        group: ":pleroma",
        key: ":chat",
        value: [enabled: false]
      })

      assert capture_log(fn -> TransferTask.start_link([]) end) =~ "pleroma restarted"
    end

    test "on reboot time subkey" do
      captcha = Application.get_env(:pleroma, Pleroma.Captcha)
      on_exit(fn -> Application.put_env(:pleroma, Pleroma.Captcha, captcha) end)

      ConfigDB.create(%{
        group: ":pleroma",
        key: "Pleroma.Captcha",
        value: [seconds_valid: 60]
      })

      assert capture_log(fn -> TransferTask.start_link([]) end) =~ "pleroma restarted"
    end

    test "don't restart pleroma on reboot time key and subkey if there is false flag" do
      chat = Application.get_env(:pleroma, :chat)
      captcha = Application.get_env(:pleroma, Pleroma.Captcha)

      on_exit(fn ->
        Application.put_env(:pleroma, :chat, chat)
        Application.put_env(:pleroma, Pleroma.Captcha, captcha)
      end)

      ConfigDB.create(%{
        group: ":pleroma",
        key: ":chat",
        value: [enabled: false]
      })

      ConfigDB.create(%{
        group: ":pleroma",
        key: "Pleroma.Captcha",
        value: [seconds_valid: 60]
      })

      refute String.contains?(
               capture_log(fn -> TransferTask.load_and_update_env([], false) end),
               "pleroma restarted"
             )
    end
  end
end
