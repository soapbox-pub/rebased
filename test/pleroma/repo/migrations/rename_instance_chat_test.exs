defmodule Pleroma.Repo.Migrations.RenameInstanceChatTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import Pleroma.Tests.Helpers
  alias Pleroma.ConfigDB

  setup do: clear_config([:instance])
  setup do: clear_config([:chat])
  setup_all do: require_migration("20200806175913_rename_instance_chat")

  describe "up/0" do
    test "migrates chat settings to shout", %{migration: migration} do
      insert(:config, group: :pleroma, key: :instance, value: [chat_limit: 6000])
      insert(:config, group: :pleroma, key: :chat, value: [enabled: true])

      assert migration.up() == :ok

      assert ConfigDB.get_by_params(%{group: :pleroma, key: :chat}) == nil
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :instance}) == nil

      assert ConfigDB.get_by_params(%{group: :pleroma, key: :shout}).value == [
               limit: 6000,
               enabled: true
             ]
    end

    test "does nothing when chat settings are not set", %{migration: migration} do
      assert migration.up() == :noop
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :chat}) == nil
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :shout}) == nil
    end
  end

  describe "down/0" do
    test "migrates shout settings back to instance and chat", %{migration: migration} do
      insert(:config, group: :pleroma, key: :shout, value: [limit: 42, enabled: true])

      assert migration.down() == :ok

      assert ConfigDB.get_by_params(%{group: :pleroma, key: :chat}).value == [enabled: true]
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :instance}).value == [chat_limit: 42]
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :shout}) == nil
    end

    test "does nothing when shout settings are not set", %{migration: migration} do
      assert migration.down() == :noop
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :chat}) == nil
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :instance}) == nil
      assert ConfigDB.get_by_params(%{group: :pleroma, key: :shout}) == nil
    end
  end
end
