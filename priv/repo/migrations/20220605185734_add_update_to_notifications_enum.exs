defmodule Pleroma.Repo.Migrations.AddUpdateToNotificationsEnum do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    """
    alter type notification_type add value 'update'
    """
    |> execute()
  end

  # 20210717000000_add_poll_to_notifications_enum.exs
  def down do
    alter table(:notifications) do
      modify(:type, :string)
    end

    """
    delete from notifications where type = 'update'
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
      'poll'
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
