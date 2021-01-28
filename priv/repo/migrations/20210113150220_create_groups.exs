defmodule Pleroma.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:owner_id, references(:users, type: :uuid, on_delete: :nilify_all))
      add(:name, :text)
      add(:description, :text)
      add(:members_collection, :text)

      timestamps()
    end
  end
end
