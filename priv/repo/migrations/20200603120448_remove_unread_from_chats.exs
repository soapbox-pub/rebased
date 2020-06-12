defmodule Pleroma.Repo.Migrations.RemoveUnreadFromChats do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      remove(:unread, :integer, default: 0)
    end
  end
end
