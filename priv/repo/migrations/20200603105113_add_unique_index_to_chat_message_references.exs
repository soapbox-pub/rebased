# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUniqueIndexToChatMessageReferences do
  use Ecto.Migration

  def change do
    create(unique_index(:chat_message_references, [:object_id, :chat_id]))
  end
end
