defmodule Pleroma.Repo.Migrations.AddDiscloseClientToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:disclose_client, :boolean, default: true)
    end
  end

  def down do
    alter table(:users) do
      remove(:disclose_client)
    end
  end
end
