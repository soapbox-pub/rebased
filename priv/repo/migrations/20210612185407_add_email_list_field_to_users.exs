defmodule Pleroma.Repo.Migrations.AddEmailListFieldToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accepts_email_list, :boolean, default: false)
    end
  end
end
