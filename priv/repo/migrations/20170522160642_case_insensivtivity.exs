defmodule Pleroma.Repo.Migrations.CaseInsensivtivity do
  use Ecto.Migration

  def up do
    execute ("create extension if not exists citext")
    alter table(:users) do
      modify :email, :citext
      modify :nickname, :citext
    end
  end

  def down do
    alter table(:users) do
      modify :email, :string
      modify :nickname, :string
    end
    execute ("drop extension if exists citext")
  end
end
