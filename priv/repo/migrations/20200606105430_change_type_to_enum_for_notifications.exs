# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ChangeTypeToEnumForNotifications do
  use Ecto.Migration

  def up do
    """
    create type notification_type as enum (
      'follow',
      'follow_request',
      'mention',
      'move',
      'pleroma:emoji_reaction',
      'pleroma:chat_mention',
      'reblog',
      'favourite'
    )
    """
    |> execute()

    """
    alter table notifications 
    alter column type type notification_type using (type::notification_type)
    """
    |> execute()
  end

  def down do
    alter table(:notifications) do
      modify(:type, :string)
    end

    """
    drop type notification_type
    """
    |> execute()
  end
end
