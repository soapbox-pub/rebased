defmodule Pleroma.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create table(:registrations) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :provider, :string
      add :uid, :string
      add :info, :map, default: %{}

      timestamps()
    end

    create unique_index(:registrations, [:provider, :uid])
    create unique_index(:registrations, [:user_id, :provider])
  end
end
