# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUnreadIndexToConversationParticipation do
  use Ecto.Migration

  def change do
    create(
      index(:conversation_participations, [:user_id],
        where: "read = false",
        name: "unread_conversation_participation_count_index"
      )
    )
  end
end
