defmodule Pleroma.Repo.Migrations.AddTagsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:tags, {:array, :string})
    end

    create_if_not_exists(index(:users, [:tags], using: :gin))
  end
end
