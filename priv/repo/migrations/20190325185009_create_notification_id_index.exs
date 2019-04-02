defmodule Pleroma.Repo.Migrations.CreateNotificationIdIndex do
  use Ecto.Migration

  def change do
  create index(:notifications, ["id desc nulls last"])
  end
end
