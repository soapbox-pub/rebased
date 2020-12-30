defmodule Pleroma.Repo.Migrations.AddPleromaReportTypeToEnumForNotifications do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    """
    alter type notification_type add value 'pleroma:report'
    """
    |> execute()
  end

  def down do
    alter table(:notifications) do
      modify(:type, :string)
    end

    """
    delete from notifications where type = 'pleroma:report'
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
end
