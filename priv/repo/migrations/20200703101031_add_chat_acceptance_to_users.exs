# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddChatAcceptanceToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:accepts_chat_messages, :boolean, nullable: true)
    end

    execute("update users set accepts_chat_messages = true where local = true")
  end

  def down do
    alter table(:users) do
      remove(:accepts_chat_messages)
    end
  end
end
