defmodule Pleroma.Repo.Migrations.CaseInsensivtivity do
  use Ecto.Migration

  # Two-steps alters are intentional.
  # When alter of 2 columns is done in a single operation,
  # inconsistent failures happen because of index on `email` column.

  def up do
    execute("create extension if not exists citext")

    alter table(:users) do
      modify(:email, :citext)
    end

    alter table(:users) do
      modify(:nickname, :citext)
    end
  end

  def down do
    alter table(:users) do
      modify(:email, :string)
    end

    alter table(:users) do
      modify(:nickname, :string)
    end

    execute("drop extension if exists citext")
  end
end
