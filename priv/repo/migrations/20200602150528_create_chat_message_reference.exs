# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateChatMessageReference do
  use Ecto.Migration

  def change do
    create table(:chat_message_references, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:chat_id, references(:chats, on_delete: :delete_all), null: false)
      add(:object_id, references(:objects, on_delete: :delete_all), null: false)
      add(:seen, :boolean, default: false, null: false)

      timestamps()
    end

    create(index(:chat_message_references, [:chat_id, "id desc"]))
  end
end
