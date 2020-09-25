defmodule Pleroma.Repo.Migrations.MakeUserIdsCI do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify(:uri, :citext)
    end

    create(unique_index(:users, :uri))
  end

  def don do
    drop(unique_index(:users, :uri))

    alter table(:users) do
      modify(:uri, :text)
    end
  end
end
