# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MoveWelcomeSettingsTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  import Pleroma.Tests.Helpers
  alias Pleroma.ConfigDB

  setup_all do: require_migration("20200724133313_move_welcome_settings")

  describe "up/0" do
    test "converts welcome settings", %{migration: migration} do
      insert(:config,
        group: :pleroma,
        key: :instance,
        value: [
          welcome_message: "Test message",
          welcome_user_nickname: "jimm",
          name: "Pleroma"
        ]
      )

      migration.up()
      instance_config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})
      welcome_config = ConfigDB.get_by_params(%{group: :pleroma, key: :welcome})

      assert instance_config.value == [name: "Pleroma"]

      assert welcome_config.value == [
               direct_message: %{
                 enabled: true,
                 message: "Test message",
                 sender_nickname: "jimm"
               },
               email: %{
                 enabled: false,
                 html: "Welcome to <%= instance_name %>",
                 sender: nil,
                 subject: "Welcome to <%= instance_name %>",
                 text: "Welcome to <%= instance_name %>"
               }
             ]
    end

    test "does nothing when message empty", %{migration: migration} do
      insert(:config,
        group: :pleroma,
        key: :instance,
        value: [
          welcome_message: "",
          welcome_user_nickname: "jimm",
          name: "Pleroma"
        ]
      )

      migration.up()
      instance_config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})
      refute ConfigDB.get_by_params(%{group: :pleroma, key: :welcome})
      assert instance_config.value == [name: "Pleroma"]
    end

    test "does nothing when welcome_message not set", %{migration: migration} do
      insert(:config,
        group: :pleroma,
        key: :instance,
        value: [welcome_user_nickname: "jimm", name: "Pleroma"]
      )

      migration.up()
      instance_config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})
      refute ConfigDB.get_by_params(%{group: :pleroma, key: :welcome})
      assert instance_config.value == [name: "Pleroma"]
    end
  end

  describe "down/0" do
    test "revert new settings to old when instance setting not exists", %{migration: migration} do
      insert(:config,
        group: :pleroma,
        key: :welcome,
        value: [
          direct_message: %{
            enabled: true,
            message: "Test message",
            sender_nickname: "jimm"
          },
          email: %{
            enabled: false,
            html: "Welcome to <%= instance_name %>",
            sender: nil,
            subject: "Welcome to <%= instance_name %>",
            text: "Welcome to <%= instance_name %>"
          }
        ]
      )

      migration.down()

      refute ConfigDB.get_by_params(%{group: :pleroma, key: :welcome})
      instance_config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})

      assert instance_config.value == [
               welcome_user_nickname: "jimm",
               welcome_message: "Test message"
             ]
    end

    test "revert new settings to old when instance setting exists", %{migration: migration} do
      insert(:config, group: :pleroma, key: :instance, value: [name: "Pleroma App"])

      insert(:config,
        group: :pleroma,
        key: :welcome,
        value: [
          direct_message: %{
            enabled: true,
            message: "Test message",
            sender_nickname: "jimm"
          },
          email: %{
            enabled: false,
            html: "Welcome to <%= instance_name %>",
            sender: nil,
            subject: "Welcome to <%= instance_name %>",
            text: "Welcome to <%= instance_name %>"
          }
        ]
      )

      migration.down()

      refute ConfigDB.get_by_params(%{group: :pleroma, key: :welcome})
      instance_config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})

      assert instance_config.value == [
               name: "Pleroma App",
               welcome_user_nickname: "jimm",
               welcome_message: "Test message"
             ]
    end
  end
end
