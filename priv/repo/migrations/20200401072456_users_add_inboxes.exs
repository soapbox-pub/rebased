defmodule Pleroma.Repo.Migrations.UsersAddInboxes do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists(:inbox, :text)
      add_if_not_exists(:shared_inbox, :text)
    end

    execute("UPDATE users SET inbox = source_data->>'inbox'")
    execute("UPDATE users SET shared_inbox = source_data->'endpoints'->>'sharedInbox'")
  end

  def down do
    alter table(:users) do
      remove_if_exists(:inbox, :text)
      remove_if_exists(:shared_inbox, :text)
    end
  end
end
