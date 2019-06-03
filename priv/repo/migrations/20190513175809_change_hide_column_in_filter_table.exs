defmodule Pleroma.Repo.Migrations.ChangeHideColumnInFilterTable do
  use Ecto.Migration

  def change do
    alter table(:filters) do
      modify :hide, :boolean, default: false
    end
  end
end
