# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
