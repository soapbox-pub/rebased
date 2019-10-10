defmodule Pleroma.Repo.Migrations.ChangeHideColumnInFilterTable do
  use Ecto.Migration

  def up do
    alter table(:filters) do
      modify(:hide, :boolean, default: false)
    end
  end

  def down do
    alter table(:filters) do
      modify(:hide, :boolean)
    end
  end
end
