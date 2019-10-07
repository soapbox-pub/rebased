defmodule Pleroma.Repo.Migrations.AddUnreadConversationCountToUserInfo do
  use Ecto.Migration

  def up do
    execute("""
    update users set info = jsonb_set(info, '{unread_conversation_count}', 0::varchar::jsonb, true) where local=true
    """)
  end

  def down, do: :ok
end
