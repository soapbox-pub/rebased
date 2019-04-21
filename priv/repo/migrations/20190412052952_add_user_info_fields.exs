defmodule Pleroma.Repo.Migrations.AddEmailNotificationsToUserInfo do
  use Ecto.Migration

  def up do
    execute("
    UPDATE users
    SET info = info || '{
      \"email_notifications\": {
        \"digest\": false
      }
    }'")
  end

  def down do
    execute("
      UPDATE users
      SET info = info - 'email_notifications'
    ")
  end
end
