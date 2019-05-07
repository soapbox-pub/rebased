# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add(:ap_id, :string, null: false)
      timestamps()
    end

    create table(:conversation_participations) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:conversation_id, references(:conversations, on_delete: :delete_all))
      add(:read, :boolean, default: false)

      timestamps()
    end

    create index(:conversation_participations, [:conversation_id])
    create unique_index(:conversation_participations, [:user_id, :conversation_id])
    create unique_index(:conversations, [:ap_id])
  end
end
