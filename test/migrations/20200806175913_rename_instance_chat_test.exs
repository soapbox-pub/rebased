defmodule Pleroma.Repo.Migrations.RenameInstanceChatTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import Pleroma.Tests.Helpers
  alias Pleroma.ConfigDB

  setup do: clear_config([:instance])
  setup do: clear_config([:chat])
  setup_all do: require_migration("20200806175913_rename_instance_chat")

  test "up/0 migrates chat settings to shout", %{migration: migration} do
    insert(:config, group: :pleroma, key: :instance, value: ["chat_limit: 6000"])
    insert(:config, group: :pleroma, key: :chat, value: ["enabled: true"])

    migration.up()

    assert nil == ConfigDB.get_by_params(%{group: :pleroma, key: :chat})

    assert %{value: [limit: 6000, enabled: true]} == ConfigDB.get_by_params(%{group: :pleroma, key: :shout})
  end
end
