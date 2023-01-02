# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveUnreadFromChats do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      remove(:unread, :integer, default: 0)
    end
  end
end
