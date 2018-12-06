defmodule Pleroma.Repo.Migrations.AddTagsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tags, {:array, :string}
    end

    create index(:users, [:tags], using: :gin)
  end
end
