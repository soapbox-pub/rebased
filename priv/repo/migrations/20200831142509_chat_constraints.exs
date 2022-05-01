# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ChatConstraints do
  use Ecto.Migration

  def change do
    remove_orphans = """
    delete from chats where not exists(select id from users where ap_id = chats.recipient);
    """

    execute(remove_orphans)

    drop(constraint(:chats, "chats_user_id_fkey"))

    alter table(:chats) do
      modify(:user_id, references(:users, type: :uuid, on_delete: :delete_all))

      modify(
        :recipient,
        references(:users, column: :ap_id, type: :string, on_delete: :delete_all)
      )
    end
  end
end
