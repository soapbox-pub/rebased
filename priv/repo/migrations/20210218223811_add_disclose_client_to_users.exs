defmodule Pleroma.Repo.Migrations.AddDiscloseClientToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:disclose_client, :boolean, default: true)
    end
  end
end
