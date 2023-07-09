# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddPollToNotificationsEnum do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    """
    alter type notification_type add value 'poll'
    """
    |> execute()
  end

  def down do
    alter table(:notifications) do
      modify(:type, :string)
    end

    """
    delete from notifications where type = 'poll'
    """
    |> execute()

    """
    drop type if exists notification_type
    """
    |> execute()

    """
    create type notification_type as enum (
      'follow',
      'follow_request',
      'mention',
      'move',
      'pleroma:emoji_reaction',
      'pleroma:chat_mention',
      'reblog',
      'favourite',
      'pleroma:report'
    )
    """
    |> execute()

    """
    alter table notifications
    alter column type type notification_type using (type::notification_type)
    """
    |> execute()
  end
end
