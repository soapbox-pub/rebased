defmodule Pleroma.Repo.Migrations.CreateNotificationIdIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:notifications, ["id desc nulls last"]))
  end
end
