defmodule Pleroma.Repo.Migrations.ChangeObjectIdToFlake do
  @moduledoc """
  Convert object IDs to FlakeIds.
  Fortunately only a few tables have a foreign key to objects. Update them.
  """
  use Ecto.Migration

  @delete_duplicate_ap_id_objects_query """
  DELETE FROM objects
  WHERE id IN (
    SELECT
        id
    FROM (
        SELECT
            id,
            row_number() OVER w as rnum
        FROM objects
        WHERE data->>'id' IS NOT NULL
        WINDOW w AS (
            PARTITION BY data->>'id'
            ORDER BY id
        )
    ) t
  WHERE t.rnum > 1)
  """

  @convert_objects_int_ids_to_flake_ids_query """
  alter table objects
  drop constraint objects_pkey cascade,
  alter column id drop default,
  alter column id set data type uuid using cast( lpad( to_hex(id), 32, '0') as uuid),
  add primary key (id)
  """

  def up do
    # Lock tables to avoid a running server meddling with our transaction
    execute("LOCK TABLE objects")
    execute("LOCK TABLE data_migration_failed_ids")
    execute("LOCK TABLE chat_message_references")
    execute("LOCK TABLE deliveries")
    execute("LOCK TABLE hashtags_objects")

    # Switch object IDs to FlakeIds
    execute(fn ->
      try do
        repo().query!(@convert_objects_int_ids_to_flake_ids_query)
      rescue
        e in Postgrex.Error ->
          # Handling of error 23505, "unique_violation": https://git.pleroma.social/pleroma/pleroma/-/issues/2771
          with %{postgres: %{pg_code: "23505"}} <- e do
            repo().query!(@delete_duplicate_ap_id_objects_query)
            repo().query!(@convert_objects_int_ids_to_flake_ids_query)
          else
            _ -> raise e
          end
      end
    end)

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
    add constraint deliveries_object_id_fkey foreign key (object_id) references objects(id) on delete cascade
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
