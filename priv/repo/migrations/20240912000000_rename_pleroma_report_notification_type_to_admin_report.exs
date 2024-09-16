# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenamePleromaReportNotificationTypeToAdminReport do
  use Ecto.Migration

  def up do
    alter table(:notifications) do
      modify(:type, :string)
    end

    """
    update notifications
    set type = 'admin.report'
    where type = 'pleroma:report'
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
      'admin.report',
      'poll',
      'status',
      'update',
      'pleroma:participation_accepted',
      'pleroma:participation_request',
      'pleroma:event_reminder',
      'pleroma:event_update',
      'bite'
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
    update notifications
    set type = 'pleroma:report'
    where type = 'admin.report'
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
      'pleroma:report',
      'poll',
      'status',
      'update',
      'pleroma:participation_accepted',
      'pleroma:participation_request',
      'pleroma:event_reminder',
      'pleroma:event_update',
      'bite'
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
