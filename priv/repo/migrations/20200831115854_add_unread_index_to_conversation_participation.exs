defmodule Pleroma.Repo.Migrations.AddUnreadIndexToConversationParticipation do
  use Ecto.Migration

  def change do
    create(
      index(:conversation_participations, [:user_id],
        where: "read = false",
        name: "unread_conversation_participation_count_index"
      )
    )
  end
end
