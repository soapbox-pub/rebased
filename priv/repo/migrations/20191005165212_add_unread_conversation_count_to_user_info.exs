# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUnreadConversationCountToUserInfo do
  use Ecto.Migration

  def up do
    execute("""
    update users set info = jsonb_set(info, '{unread_conversation_count}', 0::varchar::jsonb, true) where local=true
    """)
  end

  def down, do: :ok
end
