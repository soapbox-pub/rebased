defmodule Pleroma.Repo.Migrations.CombineActivitiesAndObjects do
  use Ecto.Migration
  require Integer

  alias Pleroma.Clippy
  alias Pleroma.Repo

  import Ecto.Query

  @function_name "update_status_visibility_counter_cache"
  @trigger_name "status_visibility_counter_cache_trigger"

  def up do
    clippy = start_clippy_heartbeats()

    # Lock both tables to avoid a running server meddling with our transaction
    execute("LOCK TABLE activities")
    execute("LOCK TABLE objects")

    # Add missing fields to objects table
    alter table(:objects) do
      add(:local, :boolean, null: false, default: true)
      add(:actor, :string)
      add(:recipients, {:array, :string}, default: [])
    end

    # Add missing indexes to objects
    create_if_not_exists(index(:objects, [:local]))
    create_if_not_exists(index(:objects, [:actor, "id DESC NULLS LAST"]))
    create_if_not_exists(index(:objects, [:recipients], using: :gin))

    # Intentionally omit these. According to LiveDashboard they're not used:
    #
    # create_if_not_exists(
    #   index(:objects, ["(data->'to')"], name: :objects_to_index, using: :gin)
    # )
    #
    # create_if_not_exists(
    #   index(:objects, ["(data->'cc')"], name: :objects_cc_index, using: :gin)
    # )

    create_if_not_exists(
      index(:objects, ["(data->>'actor')", "inserted_at desc"], name: :objects_actor_index)
    )

    # Some obscure Fediverse backends (WordPress, Juick) send a Create and a Note
    # with the exact same ActivityPub ID. This violates the spec and doesn't
    # work in the new system. WordPress devs were notified.
    execute(
      "DELETE FROM activities USING objects WHERE activities.data->>'id' = objects.data->>'id'"
    )

    # Copy all activities into the newly formatted objects table
    execute(
      "INSERT INTO objects (id, data, local, actor, recipients, inserted_at, updated_at) SELECT id, data, local, actor, recipients, inserted_at, updated_at FROM activities ON CONFLICT DO NOTHING"
    )

    # Update notifications foreign key
    execute("alter table notifications drop constraint notifications_activity_id_fkey")

    execute(
      "alter table notifications add constraint notifications_object_id_fkey foreign key (activity_id) references objects(id) on delete cascade"
    )

    # Update bookmarks foreign key
    execute("alter table bookmarks drop constraint bookmarks_activity_id_fkey")

    execute(
      "alter table bookmarks add constraint bookmarks_object_id_fkey foreign key (activity_id) references objects(id) on delete cascade"
    )

    # Update report notes foreign key
    execute("alter table report_notes drop constraint report_notes_activity_id_fkey")

    execute(
      "alter table report_notes add constraint report_notes_object_id_fkey foreign key (activity_id) references objects(id)"
    )

    # Nuke the old activities table
    execute("drop table activities")

    # Update triggers
    """
    CREATE TRIGGER #{@trigger_name}
    BEFORE
      INSERT
      OR UPDATE of recipients, data
      OR DELETE
    ON objects
    FOR EACH ROW
      EXECUTE PROCEDURE #{@function_name}();
    """
    |> execute()

    execute("drop function if exists thread_visibility(actor varchar, activity_id varchar)")
    execute(update_thread_visibility())

    flush()

    stop_clippy_heartbeats(clippy)
  end

  def down do
    raise "Lol, there's no going back from this."
  end

  # It acts upon objects instead of activities now
  def update_thread_visibility do
    """
    CREATE OR REPLACE FUNCTION thread_visibility(actor varchar, object_id varchar) RETURNS boolean AS $$
    DECLARE
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
      child objects%ROWTYPE;
      object objects%ROWTYPE;
      author_fa varchar;
      valid_recipients varchar[];
      actor_user_following varchar[];
    BEGIN
      --- Fetch actor following
      SELECT array_agg(following.follower_address) INTO actor_user_following FROM following_relationships
      JOIN users ON users.id = following_relationships.follower_id
      JOIN users AS following ON following.id = following_relationships.following_id
      WHERE users.ap_id = actor;

      --- Fetch our initial object.
      SELECT * INTO object FROM objects WHERE objects.data->>'id' = object_id;

      LOOP
        --- Ensure that we have an object before continuing.
        --- If we don't, the thread is not satisfiable.
        IF object IS NULL THEN
          RETURN false;
        END IF;

        --- We only care about Create objects.
        IF object.data->>'type' != 'Create' THEN
          RETURN true;
        END IF;

        --- Normalize the child object into child.
        SELECT * INTO child FROM objects
        WHERE COALESCE(object.data->'object'->>'id', object.data->>'object') = objects.data->>'id';

        --- Fetch the author's AS2 following collection.
        SELECT COALESCE(users.follower_address, '') INTO author_fa FROM users WHERE users.ap_id = object.actor;

        --- Prepare valid recipients array.
        valid_recipients := ARRAY[actor, public];
        IF ARRAY[author_fa] && actor_user_following THEN
          valid_recipients := valid_recipients || author_fa;
        END IF;

        --- Check visibility.
        IF NOT valid_recipients && object.recipients THEN
          --- object not visible, break out of the loop
          RETURN false;
        END IF;

        --- If there's a parent, load it and do this all over again.
        IF (child.data->'inReplyTo' IS NOT NULL) AND (child.data->'inReplyTo' != 'null'::jsonb) THEN
          SELECT * INTO object FROM objects
          WHERE child.data->>'inReplyTo' = objects.data->>'id';
        ELSE
          RETURN true;
        END IF;
      END LOOP;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """
  end

  defp start_clippy_heartbeats() do
    count = from(a in "activities", select: count(a.id)) |> Repo.one!()

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
