defmodule Pleroma.Repo.Migrations.ChangeObjectIdToFlake do
  @moduledoc """
  Convert object IDs to FlakeIds.
  Fortunately only a few tables have a foreign key to objects. Update them.
  """
  use Ecto.Migration
  require Integer

  alias Pleroma.Clippy
  alias Pleroma.Repo

  import Ecto.Query

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
    clippy = start_clippy_heartbeats()

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

    flush()

    stop_clippy_heartbeats(clippy)
  end

  def down do
    raise "This migration can't be reversed"
  end

  defp start_clippy_heartbeats() do
    count = from(o in "objects", select: count(o.id)) |> Repo.one!()

    if count > 5000 do
      heartbeat_interval = :timer.minutes(2) + :timer.seconds(30)

      all_tips =
        Clippy.tips() ++
          [
            "The migration is still running, maybe it's time for another “tea”?",
            "Happy rabbits practice a cute behavior known as a\n“binky:” they jump up in the air\nand twist\nand spin around!",
            "Nothing and everything.\n\nI still work.",
            "Pleroma runs on a Raspberry Pi!\n\n  … but this migration will take forever if you\nactually run on a raspberry pi",
            "Status? Stati? Post? Note? Toot?\nRepeat? Reboost? Boost? Retweet? Retoot??\n\nI-I'm confused."
          ]

      heartbeat = fn heartbeat, runs, all_tips, tips ->
        tips =
          if Integer.is_even(runs) do
            tips = if tips == [], do: all_tips, else: tips
            [tip | tips] = Enum.shuffle(tips)
            Clippy.puts(tip)
            tips
          else
            IO.puts(
              "\n -- #{DateTime.to_string(DateTime.utc_now())} Migration still running, please wait…\n"
            )

            tips
          end

        :timer.sleep(heartbeat_interval)
        heartbeat.(heartbeat, runs + 1, all_tips, tips)
      end

      Clippy.puts([
        [:red, :bright, "It looks like you are running an older instance!"],
        [""],
        [:bright, "This migration may take a long time", :reset, " -- so you probably should"],
        ["go drink a cofe, or a tea, or a beer, a whiskey, a vodka,"],
        ["while it runs to deal with your temporary fediverse pause!"]
      ])

      :timer.sleep(heartbeat_interval)
      spawn_link(fn -> heartbeat.(heartbeat, 1, all_tips, []) end)
    end
  end

  defp stop_clippy_heartbeats(pid) do
    if pid do
      Process.unlink(pid)
      Process.exit(pid, :kill)
      Clippy.puts([[:green, :bright, "Hurray!!", "", "", "Migration completed!"]])
    end
  end
end
