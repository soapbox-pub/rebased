defmodule Pleroma.Repo.Migrations.ChangeChatIdToFlake do
  use Ecto.Migration

  def up do
    execute("""
    alter table chats
    drop constraint chats_pkey cascade,
    alter column id drop default,
    alter column id set data type uuid using cast( lpad( to_hex(id), 32, '0') as uuid),
    add primary key (id)
    """)

    execute("""
    alter table chat_message_references
    alter column chat_id set data type uuid using cast( lpad( to_hex(chat_id), 32, '0') as uuid),
    add constraint chat_message_references_chat_id_fkey foreign key (chat_id) references chats(id) on delete cascade
    """)
  end

  def down do
    :ok
  end
end
