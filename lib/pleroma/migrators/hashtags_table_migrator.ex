# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.HashtagsTableMigrator do
  defmodule State do
    use Pleroma.Migrators.Support.BaseMigratorState

    @impl Pleroma.Migrators.Support.BaseMigratorState
    defdelegate data_migration(), to: Pleroma.DataMigration, as: :populate_hashtags_table
  end

  use Pleroma.Migrators.Support.BaseMigrator

  alias Pleroma.Hashtag
  alias Pleroma.Migrators.Support.BaseMigrator
  alias Pleroma.Object

  @impl BaseMigrator
  def feature_config_path, do: [:features, :improved_hashtag_timeline]

  @impl BaseMigrator
  def fault_rate_allowance, do: Config.get([:populate_hashtags_table, :fault_rate_allowance], 0)

  @impl BaseMigrator
  def perform do
    data_migration_id = data_migration_id()
    max_processed_id = get_stat(:max_processed_id, 0)

    Logger.info("Transferring embedded hashtags to `hashtags` (from oid: #{max_processed_id})...")

    query()
    |> where([object], object.id > ^max_processed_id)
    |> Repo.chunk_stream(100, :batches, timeout: :infinity)
    |> Stream.each(fn objects ->
      object_ids = Enum.map(objects, & &1.id)

      results = Enum.map(objects, &transfer_object_hashtags(&1))

      failed_ids =
        results
        |> Enum.filter(&(elem(&1, 0) == :error))
        |> Enum.map(&elem(&1, 1))

      # Count of objects with hashtags: `{:noop, id}` is returned for objects having other AS2 tags
      chunk_affected_count =
        results
        |> Enum.filter(&(elem(&1, 0) == :ok))
        |> length()

      for failed_id <- failed_ids do
        _ =
          Repo.query(
            "INSERT INTO data_migration_failed_ids(data_migration_id, record_id) " <>
              "VALUES ($1, $2) ON CONFLICT DO NOTHING;",
            [data_migration_id, failed_id]
          )
      end

      _ =
        Repo.query(
          "DELETE FROM data_migration_failed_ids " <>
            "WHERE data_migration_id = $1 AND record_id = ANY($2)",
          [data_migration_id, object_ids -- failed_ids]
        )

      max_object_id = Enum.at(object_ids, -1)

      put_stat(:max_processed_id, max_object_id)
      increment_stat(:iteration_processed_count, length(object_ids))
      increment_stat(:processed_count, length(object_ids))
      increment_stat(:failed_count, length(failed_ids))
      increment_stat(:affected_count, chunk_affected_count)
      put_stat(:records_per_second, records_per_second())
      persist_state()

      # A quick and dirty approach to controlling the load this background migration imposes
      sleep_interval = Config.get([:populate_hashtags_table, :sleep_interval_ms], 0)
      Process.sleep(sleep_interval)
    end)
    |> Stream.run()
  end

  @impl BaseMigrator
  def query do
    # Note: most objects have Mention-type AS2 tags and no hashtags (but we can't filter them out)
    # Note: not checking activity type, expecting remove_non_create_objects_hashtags/_ to clean up
    from(
      object in Object,
      where:
        fragment("(?)->'tag' IS NOT NULL AND (?)->'tag' != '[]'::jsonb", object.data, object.data),
      select: %{
        id: object.id,
        tag: fragment("(?)->'tag'", object.data)
      }
    )
    |> join(:left, [o], hashtags_objects in fragment("SELECT object_id FROM hashtags_objects"),
      on: hashtags_objects.object_id == o.id
    )
    |> where([_o, hashtags_objects], is_nil(hashtags_objects.object_id))
  end

  @spec transfer_object_hashtags(Map.t()) :: {:noop | :ok | :error, integer()}
  defp transfer_object_hashtags(object) do
    embedded_tags = if Map.has_key?(object, :tag), do: object.tag, else: object.data["tag"]
    hashtags = Object.object_data_hashtags(%{"tag" => embedded_tags})

    if Enum.any?(hashtags) do
      transfer_object_hashtags(object, hashtags)
    else
      {:noop, object.id}
    end
  end

  defp transfer_object_hashtags(object, hashtags) do
    Repo.transaction(fn ->
      with {:ok, hashtag_records} <- Hashtag.get_or_create_by_names(hashtags) do
        maps = Enum.map(hashtag_records, &%{hashtag_id: &1.id, object_id: object.id})
        base_error = "ERROR when inserting hashtags_objects for object with id #{object.id}"

        try do
          with {rows_count, _} when is_integer(rows_count) <-
                 Repo.insert_all("hashtags_objects", maps, on_conflict: :nothing) do
            object.id
          else
            e ->
              Logger.error("#{base_error}: #{inspect(e)}")
              Repo.rollback(object.id)
          end
        rescue
          e ->
            Logger.error("#{base_error}: #{inspect(e)}")
            Repo.rollback(object.id)
        end
      else
        e ->
          error = "ERROR: could not create hashtags for object #{object.id}: #{inspect(e)}"
          Logger.error(error)
          Repo.rollback(object.id)
      end
    end)
  end

  @impl BaseMigrator
  def retry_failed do
    data_migration_id = data_migration_id()

    failed_objects_query()
    |> Repo.chunk_stream(100, :one)
    |> Stream.each(fn object ->
      with {res, _} when res != :error <- transfer_object_hashtags(object) do
        _ =
          Repo.query(
            "DELETE FROM data_migration_failed_ids " <>
              "WHERE data_migration_id = $1 AND record_id = $2",
            [data_migration_id, object.id]
          )
      end
    end)
    |> Stream.run()

    put_stat(:failed_count, failures_count())
    persist_state()

    force_continue()
  end

  defp failed_objects_query do
    from(o in Object)
    |> join(:inner, [o], dmf in fragment("SELECT * FROM data_migration_failed_ids"),
      on: dmf.record_id == o.id
    )
    |> where([_o, dmf], dmf.data_migration_id == ^data_migration_id())
    |> order_by([o], asc: o.id)
  end

  @doc """
  Service func to delete `hashtags_objects` for legacy objects not associated with Create activity.
  Also deletes unreferenced `hashtags` records (might occur after deletion of `hashtags_objects`).
  """
  def delete_non_create_activities_hashtags do
    hashtags_objects_cleanup_query = """
    DELETE FROM hashtags_objects WHERE object_id IN
      (SELECT DISTINCT objects.id FROM objects
        JOIN hashtags_objects ON hashtags_objects.object_id = objects.id LEFT JOIN activities
          ON COALESCE(activities.data->'object'->>'id', activities.data->>'object') =
            (objects.data->>'id')
          AND activities.data->>'type' = 'Create'
        WHERE activities.id IS NULL);
    """

    hashtags_cleanup_query = """
    DELETE FROM hashtags WHERE id IN
      (SELECT hashtags.id FROM hashtags
        LEFT OUTER JOIN hashtags_objects
          ON hashtags_objects.hashtag_id = hashtags.id
        WHERE hashtags_objects.hashtag_id IS NULL);
    """

    {:ok, %{num_rows: hashtags_objects_count}} =
      Repo.query(hashtags_objects_cleanup_query, [], timeout: :infinity)

    {:ok, %{num_rows: hashtags_count}} =
      Repo.query(hashtags_cleanup_query, [], timeout: :infinity)

    {:ok, hashtags_objects_count, hashtags_count}
  end
end
