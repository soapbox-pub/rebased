# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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
          vacuum: :boolean,
          keep_threads: :boolean,
          keep_non_public: :boolean,
          prune_orphaned_activities: :boolean
        ]
      )

    start_pleroma()

    deadline = Pleroma.Config.get([:instance, :remote_post_retention_days])
    time_deadline = NaiveDateTime.utc_now() |> NaiveDateTime.add(-(deadline * 86_400))

    log_message = "Pruning objects older than #{deadline} days"

    log_message =
      if Keyword.get(options, :keep_non_public) do
        log_message <> ", keeping non public posts"
      else
        log_message
      end

    log_message =
      if Keyword.get(options, :keep_threads) do
        log_message <> ", keeping threads intact"
      else
        log_message
      end

    log_message =
      if Keyword.get(options, :prune_orphaned_activities) do
        log_message <> ", pruning orphaned activities"
      else
        log_message
      end

    log_message =
      if Keyword.get(options, :vacuum) do
        log_message <>
          ", doing a full vacuum (you shouldn't do this as a recurring maintanance task)"
      else
        log_message
      end

    Logger.info(log_message)

    if Keyword.get(options, :keep_threads) do
      # We want to delete objects from threads where
      # 1. the newest post is still old
      # 2. none of the activities is local
      # 3. none of the activities is bookmarked
      # 4. optionally none of the posts is non-public
      deletable_context =
        if Keyword.get(options, :keep_non_public) do
          Pleroma.Activity
          |> join(:left, [a], b in Pleroma.Bookmark, on: a.id == b.activity_id)
          |> group_by([a], fragment("? ->> 'context'::text", a.data))
          |> having(
            [a],
            not fragment(
              # Posts (checked on Create Activity) is non-public
              "bool_or((not(?->'to' \\? ? OR ?->'cc' \\? ?)) and ? ->> 'type' = 'Create')",
              a.data,
              ^Pleroma.Constants.as_public(),
              a.data,
              ^Pleroma.Constants.as_public(),
              a.data
            )
          )
        else
          Pleroma.Activity
          |> join(:left, [a], b in Pleroma.Bookmark, on: a.id == b.activity_id)
          |> group_by([a], fragment("? ->> 'context'::text", a.data))
        end
        |> having([a], max(a.updated_at) < ^time_deadline)
        |> having([a], not fragment("bool_or(?)", a.local))
        |> having([_, b], fragment("max(?::text) is null", b.id))
        |> select([a], fragment("? ->> 'context'::text", a.data))

      Pleroma.Object
      |> where([o], fragment("? ->> 'context'::text", o.data) in subquery(deletable_context))
    else
      if Keyword.get(options, :keep_non_public) do
        Pleroma.Object
        |> where(
          [o],
          fragment(
            "?->'to' \\? ? OR ?->'cc' \\? ?",
            o.data,
            ^Pleroma.Constants.as_public(),
            o.data,
            ^Pleroma.Constants.as_public()
          )
        )
      else
        Pleroma.Object
      end
      |> where([o], o.updated_at < ^time_deadline)
      |> where(
        [o],
        fragment("split_part(?->>'actor', '/', 3) != ?", o.data, ^Pleroma.Web.Endpoint.host())
      )
    end
    |> Repo.delete_all(timeout: :infinity)

    if !Keyword.get(options, :keep_threads) do
      # Without the --keep-threads option, it's possible that bookmarked
      # objects have been deleted. We remove the corresponding bookmarks.
      """
      delete from public.bookmarks
      where id in (
        select b.id from public.bookmarks b
        left join public.activities a on b.activity_id = a.id
        left join public.objects o on a."data" ->> 'object' = o.data ->> 'id'
        where o.id is null
      )
      """
      |> Repo.query([], timeout: :infinity)
    end

    if Keyword.get(options, :prune_orphaned_activities) do
      # Prune activities who link to a single object
      """
      delete from public.activities
      where id in (
        select a.id from public.activities a
        left join public.objects o on a.data ->> 'object' = o.data ->> 'id'
        left join public.activities a2 on a.data ->> 'object' = a2.data ->> 'id'
        left join public.users u  on a.data ->> 'object' = u.ap_id
        where not a.local
        and jsonb_typeof(a."data" -> 'object') = 'string'
        and o.id is null
        and a2.id is null
        and u.id is null
      )
      """
      |> Repo.query([], timeout: :infinity)

      # Prune activities who link to an array of objects
      """
      delete from public.activities
      where id in (
        select a.id from public.activities a
        join json_array_elements_text((a."data" -> 'object')::json) as j on jsonb_typeof(a."data" -> 'object') = 'array'
        left join public.objects o on j.value = o.data ->> 'id'
        left join public.activities a2 on j.value = a2.data ->> 'id'
        left join public.users u  on j.value = u.ap_id
        group by a.id
        having max(o.data ->> 'id') is null
        and max(a2.data ->> 'id') is null
        and max(u.ap_id) is null
      )
      """
      |> Repo.query([], timeout: :infinity)
    end

    """
    DELETE FROM hashtags AS ht
    WHERE NOT EXISTS (
      SELECT 1 FROM hashtags_objects hto
      WHERE ht.id = hto.hashtag_id)
    """
    |> Repo.query()

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
          "(?->>'id') = associated_object_id((?))",
          o.data,
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

        Pleroma.Workers.PurgeExpiredActivity.enqueue(
          %{
            activity_id: activity.id
          },
          scheduled_at: expires_at
        )
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

    # non-exist config will not raise exception but only give >0 messages
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
          $$ LANGUAGE plpgsql",
          [],
          timeout: :infinity
        )

        shell_info("Refresh RUM index")
        Ecto.Adapters.SQL.query!(Pleroma.Repo, "UPDATE objects SET updated_at = NOW();")
      else
        Ecto.Adapters.SQL.query!(Pleroma.Repo, "DROP INDEX IF EXISTS objects_fts;")

        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          "CREATE INDEX CONCURRENTLY objects_fts ON objects USING gin(to_tsvector('#{tsconfig}', data->>'content')); ",
          [],
          timeout: :infinity
        )
      end

      shell_info(~c"Done.")
    end
  end

  # Rolls back a specific migration (leaving subsequent migrations applied).
  # WARNING: imposes a risk of unrecoverable data loss — proceed at your own responsibility.
  # Based on https://stackoverflow.com/a/53825840
  def run(["rollback", version]) do
    prompt = "SEVERE WARNING: this operation may result in unrecoverable data loss. Continue?"

    if shell_prompt(prompt, "n") in ~w(Yn Y y) do
      {_, result, _} =
        Ecto.Migrator.with_repo(Pleroma.Repo, fn repo ->
          version = String.to_integer(version)
          re = ~r/^#{version}_.*\.exs/
          path = Ecto.Migrator.migrations_path(repo)

          with {_, "" <> file} <- {:find, Enum.find(File.ls!(path), &String.match?(&1, re))},
               {_, [{mod, _} | _]} <- {:compile, Code.compile_file(Path.join(path, file))},
               {_, :ok} <- {:rollback, Ecto.Migrator.down(repo, version, mod)} do
            {:ok, "Reversed migration: #{file}"}
          else
            {:find, _} -> {:error, "No migration found with version prefix: #{version}"}
            {:compile, e} -> {:error, "Problem compiling migration module: #{inspect(e)}"}
            {:rollback, e} -> {:error, "Problem reversing migration: #{inspect(e)}"}
          end
        end)

      shell_info(inspect(result))
    end
  end
end
