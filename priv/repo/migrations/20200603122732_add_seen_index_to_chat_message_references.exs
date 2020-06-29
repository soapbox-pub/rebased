defmodule Pleroma.Repo.Migrations.AddSeenIndexToChatMessageReferences do
  use Ecto.Migration

  def change do
    create(
      index(:chat_message_references, [:chat_id],
        where: "seen = false",
        name: "unseen_messages_count_index"
      )
    )
  end
end
