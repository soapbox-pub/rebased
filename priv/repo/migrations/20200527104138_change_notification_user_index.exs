defmodule Pleroma.Repo.Migrations.ChangeNotificationUserIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:notifications, [:user_id]))
    create_if_not_exists(index(:notifications, [:user_id, "id desc nulls last"]))
  end
end
