# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Database do
  alias Pleroma.Conversation
  alias Pleroma.Maintenance
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  require Logger
  require Pleroma.Constants
  import Ecto.Query
  import Mix.Pleroma
  use Mix.Task

  @shortdoc "A collection of database related tasks"
  @moduledoc File.read!("docs/administration/CLI_tasks/database.md")

  def run(["remove_embedded_objects" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          vacuum: :boolean
        ]
      )

    start_pleroma()
    Logger.info("Removing embedded objects")

    Repo.query!(
      "update activities set data = safe_jsonb_set(data, '{object}'::text[], data->'object'->'id') where data->'object'->>'id' is not null;",
      [],
      timeout: :infinity
    )

    if Keyword.get(options, :vacuum) do
      Maintenance.vacuum("full")
    end
  end

  def run(["bump_all_conversations"]) do
    start_pleroma()
    Conversation.bump_for_all_activities()
  end

  def run(["update_users_following_followers_counts"]) do
    start_pleroma()

    Repo.transaction(
      fn ->
        from(u in User, select: u)
        |> Repo.stream()
        |> Stream.each(&User.update_follower_count/1)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  def run(["prune_objects" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          vacuum: :boolean
        ]
      )

    start_pleroma()

    deadline = Pleroma.Config.get([:instance, :remote_post_retention_days])

    Logger.info("Pruning objects older than #{deadline} days")

    time_deadline =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-(deadline * 86_400))

    from(o in Object,
      where:
        fragment(
          "?->'to' \\? ? OR ?->'cc' \\? ?",
          o.data,
          ^Pleroma.Constants.as_public(),
          o.data,
          ^Pleroma.Constants.as_public()
        ),
      where: o.inserted_at < ^time_deadline,
      where:
        fragment("split_part(?->>'actor', '/', 3) != ?", o.data, ^Pleroma.Web.Endpoint.host())
    )
    |> Repo.delete_all(timeout: :infinity)

    if Keyword.get(options, :vacuum) do
      Maintenance.vacuum("full")
    end
  end

  def run(["fix_likes_collections"]) do
    start_pleroma()

    from(object in Object,
      where: fragment("(?)->>'likes' is not null", object.data),
      select: %{id: object.id, likes: fragment("(?)->>'likes'", object.data)}
    )
    |> Pleroma.Repo.chunk_stream(100, :batches)
    |> Stream.each(fn objects ->
      ids =
        objects
        |> Enum.filter(fn object -> object.likes |> Jason.decode!() |> is_map() end)
        |> Enum.map(& &1.id)

      Object
      |> where([object], object.id in ^ids)
      |> update([object],
        set: [
          data:
            fragment(
              "safe_jsonb_set(?, '{likes}', '[]'::jsonb, true)",
              object.data
            )
        ]
      )
      |> Repo.update_all([], timeout: :infinity)
    end)
    |> Stream.run()
  end

  def run(["vacuum", args]) do
    start_pleroma()

    Maintenance.vacuum(args)
  end

  def run(["ensure_expiration"]) do
    start_pleroma()
    days = Pleroma.Config.get([:mrf_activity_expiration, :days], 365)

    Pleroma.Activity
    |> join(:inner, [a], o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE((?)->'object'->> 'id', (?)->>'object')",
          o.data,
          a.data,
          a.data
        )
    )
    |> where(local: true)
    |> where([a], fragment("(? ->> 'type'::text) = 'Create'", a.data))
    |> where([_a, o], fragment("?->>'type' = 'Note'", o.data))
    |> Pleroma.Repo.chunk_stream(100, :batches)
    |> Stream.each(fn activities ->
      Enum.each(activities, fn activity ->
        expires_at =
          activity.inserted_at
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.shift(days: days)

        Pleroma.Workers.PurgeExpiredActivity.enqueue(%{
          activity_id: activity.id,
          expires_at: expires_at
        })
      end)
    end)
    |> Stream.run()
  end

  def run(["set_text_search_config", tsconfig]) do
    start_pleroma()
    %{rows: [[tsc]]} = Ecto.Adapters.SQL.query!(Pleroma.Repo, "SHOW default_text_search_config;")
    shell_info("Current default_text_search_config: #{tsc}")

    %{rows: [[db]]} = Ecto.Adapters.SQL.query!(Pleroma.Repo, "SELECT current_database();")
    shell_info("Update default_text_search_config: #{tsconfig}")

    %{messages: msg} =
      Ecto.Adapters.SQL.query!(
        Pleroma.Repo,
        "ALTER DATABASE #{db} SET default_text_search_config = '#{tsconfig}';"
      )

    # non-exist config will not raise excpetion but only give >0 messages
    if length(msg) > 0 do
      shell_info("Error: #{inspect(msg, pretty: true)}")
    else
      rum_enabled = Pleroma.Config.get([:database, :rum_enabled])
      shell_info("Recreate index, RUM: #{rum_enabled}")

      # Note SQL below needs to be kept up-to-date with latest GIN or RUM index definition in future
      if rum_enabled do
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          "CREATE OR REPLACE FUNCTION objects_fts_update() RETURNS trigger AS $$ BEGIN
          new.fts_content := to_tsvector(new.data->>'content');
          RETURN new;
          END
          $$ LANGUAGE plpgsql"
        )

        shell_info("Refresh RUM index")
        Ecto.Adapters.SQL.query!(Pleroma.Repo, "UPDATE objects SET updated_at = NOW();")
      else
        Ecto.Adapters.SQL.query!(Pleroma.Repo, "DROP INDEX IF EXISTS objects_fts;")

        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          "CREATE INDEX objects_fts ON objects USING gin(to_tsvector('#{tsconfig}', data->>'content')); "
        )
      end

      shell_info('Done.')
    end
  end
end
