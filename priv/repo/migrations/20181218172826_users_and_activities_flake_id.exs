defmodule Pleroma.Repo.Migrations.UsersAndActivitiesFlakeId do
  use Ecto.Migration
  alias Pleroma.Clippy
  require Integer
  import Ecto.Query
  alias Pleroma.Repo

  # This migrates from int serial IDs to custom Flake:
  #   1- create a temporary uuid column
  #   2- fill this column with compatibility ids (see below)
  #   3- remove pkeys constraints
  #   4- update relation pkeys with the new ids
  #   5- rename the temporary column to id
  #   6- re-create the constraints
  def up do
    # Old serial int ids are transformed to 128bits with extra padding.
    # The application (in `Pleroma.FlakeId`) handles theses IDs properly as integers; to keep compatibility
    # with previously issued ids.
    # execute "update activities set external_id = CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid);"
    # execute "update users set external_id = CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid);"

    clippy = start_clippy_heartbeats()

    # Lock both tables to avoid a running server to meddling with our transaction
    execute("LOCK TABLE activities;")
    execute("LOCK TABLE users;")

    execute("""
      ALTER TABLE activities
      DROP CONSTRAINT activities_pkey CASCADE,
      ALTER COLUMN id DROP default,
      ALTER COLUMN id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid),
      ADD PRIMARY KEY (id);
    """)

    execute("""
    ALTER TABLE users
    DROP CONSTRAINT users_pkey CASCADE,
    ALTER COLUMN id DROP default,
    ALTER COLUMN id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid),
    ADD PRIMARY KEY (id);
    """)

    execute(
      "UPDATE users SET info = jsonb_set(info, '{pinned_activities}', array_to_json(ARRAY(select jsonb_array_elements_text(info->'pinned_activities')))::jsonb);"
    )

    # Fkeys:
    # Activities - Referenced by:
    #   TABLE "notifications" CONSTRAINT "notifications_activity_id_fkey" FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
    # Users - Referenced by:
    #  TABLE "filters" CONSTRAINT "filters_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "lists" CONSTRAINT "lists_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "notifications" CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "oauth_authorizations" CONSTRAINT "oauth_authorizations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
    #  TABLE "oauth_tokens" CONSTRAINT "oauth_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
    #  TABLE "password_reset_tokens" CONSTRAINT "password_reset_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
    #  TABLE "push_subscriptions" CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "websub_client_subscriptions" CONSTRAINT "websub_client_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)

    execute("""
    ALTER TABLE notifications
    ALTER COLUMN activity_id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(activity_id), 32, '0' ) AS uuid),
    ADD CONSTRAINT notifications_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE;
    """)

    for table <-
          ~w(notifications filters lists oauth_authorizations oauth_tokens password_reset_tokens push_subscriptions websub_client_subscriptions) do
      execute("""
      ALTER TABLE #{table}
      ALTER COLUMN user_id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(user_id), 32, '0' ) AS uuid),
      ADD CONSTRAINT #{table}_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
      """)
    end

    flush()

    stop_clippy_heartbeats(clippy)
  end

  def down, do: :ok

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
