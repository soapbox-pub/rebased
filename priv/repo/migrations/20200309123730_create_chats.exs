defmodule Pleroma.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add(:user_id, references(:users, type: :uuid))
      # Recipient is an ActivityPub id, to future-proof for group support.
      add(:recipient, :string)
      add(:unread, :integer, default: 0)
      timestamps()
    end

    # There's only one chat between a user and a recipient.
    create(index(:chats, [:user_id, :recipient], unique: true))
  end
end
