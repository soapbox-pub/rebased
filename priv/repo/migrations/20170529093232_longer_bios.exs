defmodule Pleroma.Repo.Migrations.LongerBios do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify(:bio, :text)
    end
  end

  def down do
    alter table(:users) do
      modify(:bio, :string)
    end
  end
end
