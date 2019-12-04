defmodule Pleroma.Repo.Migrations.RemoveInfoFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:info, :map, default: %{})
    end
  end
end
