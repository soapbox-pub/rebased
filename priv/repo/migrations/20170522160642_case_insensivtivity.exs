defmodule Pleroma.Repo.Migrations.CaseInsensivtivity do
  use Ecto.Migration

  def up do
    execute("create extension if not exists citext")

    drop_if_exists(index(:users, [:email]))

    alter table(:users) do
      modify(:email, :citext)
      modify(:nickname, :citext)
    end

    create_if_not_exists(index(:users, [:email]))
  end

  def down do
    alter table(:users) do
      modify(:email, :string)
      modify(:nickname, :string)
    end

    execute("drop extension if exists citext")
  end
end
