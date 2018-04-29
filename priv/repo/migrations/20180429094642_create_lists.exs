defmodule Pleroma.Repo.Migrations.CreateLists do
  use Ecto.Migration

  def change do
    create table(:lists) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :title, :string
      add :following, {:array, :string}

      timestamps()
    end

    create index(:lists, [:user_id])
  end
end
