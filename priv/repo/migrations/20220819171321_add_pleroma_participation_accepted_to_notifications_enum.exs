defmodule Pleroma.Repo.Migrations.AddPleromaParticipationAcceptedToNotificationsEnum do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    """
    alter type notification_type add value 'pleroma:participation_accepted'
    alter type notification_type add value 'pleroma:participation_request'
    """
    |> execute()
  end

  def down do
    alter table(:notifications) do
      modify(:type, :string)
    end

    """
    delete from notifications where type = 'pleroma:participation_accepted'
    delete from notifications where type = 'pleroma:participation_request'
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
      'status'
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
