# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddSeenIndexToChatMessageReferences do
  use Ecto.Migration

  def change do
    create(
      index(:chat_message_references, [:chat_id],
        where: "seen = false",
        name: "unseen_messages_count_index"
      )
    )
  end
end
