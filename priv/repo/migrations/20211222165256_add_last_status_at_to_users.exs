defmodule Pleroma.Repo.Migrations.AddLastStatusAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_status_at, :naive_datetime)
    end

    create_if_not_exists(index(:users, [:last_status_at]))
  end
end
