defmodule Pleroma.Repo.Migrations.MigrateSeenToUnreadInChatMessageReferences do
  use Ecto.Migration

  def change do
    drop(
      index(:chat_message_references, [:chat_id],
        where: "seen = false",
        name: "unseen_messages_count_index"
      )
    )

    alter table(:chat_message_references) do
      add(:unread, :boolean, default: true)
    end

    execute("update chat_message_references set unread = not seen")

    alter table(:chat_message_references) do
      modify(:unread, :boolean, default: true, null: false)
      remove(:seen, :boolean, default: false, null: false)
    end

    create(
      index(:chat_message_references, [:chat_id],
        where: "unread = true",
        name: "unread_messages_count_index"
      )
    )
  end
end
