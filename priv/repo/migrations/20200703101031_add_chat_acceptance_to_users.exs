defmodule Pleroma.Repo.Migrations.AddChatAcceptanceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accepts_chat_messages, :boolean, nullable: false, default: false)
    end

    # Looks stupid but makes the update much faster
    execute("update users set accepts_chat_messages = local where local = true")
  end
end
