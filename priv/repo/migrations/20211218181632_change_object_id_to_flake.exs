defmodule Pleroma.Repo.Migrations.ChangeObjectIdToFlake do
  @moduledoc """
  Convert object IDs to FlakeIds.
  Fortunately only a few tables have a foreign key to objects. Update them.
  """
  use Ecto.Migration

  def up do
    # Switch object IDs to FlakeIds
    execute("""
    alter table objects
    drop constraint objects_pkey cascade,
    alter column id drop default,
    alter column id set data type uuid using cast( lpad( to_hex(id), 32, '0') as uuid),
    add primary key (id)
    """)

    # Update data_migration_failed_ids
    execute("""
    alter table data_migration_failed_ids
    drop constraint data_migration_failed_ids_pkey cascade,
    alter column record_id set data type uuid using cast( lpad( to_hex(record_id), 32, '0') as uuid),
    add primary key (data_migration_id, record_id)
    """)

    # Update chat message foreign key
    execute("""
    alter table chat_message_references
    alter column object_id set data type uuid using cast( lpad( to_hex(object_id), 32, '0') as uuid),
    add constraint chat_message_references_object_id_fkey foreign key (object_id) references objects(id) on delete cascade
    """)

    # Update delivery foreign key
    execute("""
    alter table deliveries
    alter column object_id set data type uuid using cast( lpad( to_hex(object_id), 32, '0') as uuid),
    add constraint deliveries_object_id_fkey foreign key (object_id) references objects(id)
    """)

    # Update hashtag many-to-many foreign key
    execute("""
    alter table hashtags_objects
    alter column object_id set data type uuid using cast( lpad( to_hex(object_id), 32, '0') as uuid),
    add constraint hashtags_objects_object_id_fkey foreign key (object_id) references objects(id) on delete cascade
    """)
  end

  def down do
    :ok
  end
end
