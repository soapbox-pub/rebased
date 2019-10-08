defmodule Pleroma.Repo.Migrations.CreateConversationParticipationRecipientShips do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:conversation_participation_recipient_ships) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:participation_id, references(:conversation_participations, on_delete: :delete_all))
    end

    create_if_not_exists(index(:conversation_participation_recipient_ships, [:user_id]))
    create_if_not_exists(index(:conversation_participation_recipient_ships, [:participation_id]))
  end
end
