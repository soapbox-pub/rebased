defmodule Pleroma.Repo.Migrations.ResolveActivityObjectConflicts do
  @moduledoc """
  Find objects with a conflicting activity ID, and update them.
  This should only happen on servers that existed before "20181218172826_users_and_activities_flake_id".
  """
  use Ecto.Migration
  require Integer

  alias Pleroma.Clippy
  alias Pleroma.Object
  alias Pleroma.MigrationHelper.ObjectId
  alias Pleroma.Repo

  import Ecto.Query

  def up do
    clippy = start_clippy_heartbeats()

    # Lock relevant tables
    execute("LOCK TABLE objects")
    execute("LOCK TABLE chat_message_references")
    execute("LOCK TABLE deliveries")
    execute("LOCK TABLE hashtags_objects")

    # Temporarily disable triggers (and by consequence, fkey constraints)
    # https://stackoverflow.com/a/18709987
    Repo.query!("SET session_replication_role = replica")

    # Update conflicting objects
    activity_conflict_query()
    |> Repo.stream()
    |> Stream.each(&update_object!/1)
    |> Stream.run()

    # Re-enable triggers
    Repo.query!("SET session_replication_role = DEFAULT")

    flush()

    stop_clippy_heartbeats(clippy)
  end

  # Get only objects with a conflicting activity ID.
  defp activity_conflict_query() do
    join(Object, :inner, [o], a in "activities", on: a.id == o.id)
  end

  # Update the object and its relations with a newly-generated ID.
  defp update_object!(object) do
    new_id = ObjectId.flake_from_time(object.inserted_at)
    {:ok, %Object{}} = ObjectId.change_id(object, new_id)
  end

  def down do
    :ok
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
