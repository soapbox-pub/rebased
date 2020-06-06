defmodule Pleroma.Repo.Migrations.BackfillNotificationTypes do
  use Ecto.Migration

  def up do
    Pleroma.MigrationHelper.fill_in_notification_types()
  end

  def down do
  end
end
