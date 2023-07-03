defmodule Pleroma.Repo.Migrations.AddAcceptsChatMessagesIndexToUsers do
  use Ecto.Migration

  def change do
    create(index(:users, [:accepts_chat_messages]))
  end
end
