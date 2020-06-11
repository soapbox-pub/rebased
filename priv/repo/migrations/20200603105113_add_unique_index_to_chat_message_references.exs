defmodule Pleroma.Repo.Migrations.AddUniqueIndexToChatMessageReferences do
  use Ecto.Migration

  def change do
    create(unique_index(:chat_message_references, [:object_id, :chat_id]))
  end
end
