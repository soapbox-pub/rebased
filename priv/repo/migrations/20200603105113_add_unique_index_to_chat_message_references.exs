defmodule Pleroma.Repo.Migrations.BackfillChatMessageReferences do
  use Ecto.Migration

  alias Pleroma.Chat
  alias Pleroma.ChatMessageReference
  alias Pleroma.Object
  alias Pleroma.Repo

  import Ecto.Query

  def change do
    create(unique_index(:chat_message_references, [:object_id, :chat_id]))
  end
end
