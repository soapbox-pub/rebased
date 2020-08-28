defmodule Pleroma.Repo.Migrations.RemoveMagicKeyField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:magic_key, :string)
    end
  end
end
