# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.HashtagsTableMigrator do
  use GenServer

  require Logger

  import Ecto.Query

  alias __MODULE__.State
  alias Pleroma.Config
  alias Pleroma.DataMigration
  alias Pleroma.Hashtag
  alias Pleroma.Object
  alias Pleroma.Repo

  defdelegate state(), to: State, as: :get
  defdelegate put_stat(key, value), to: State, as: :put
  defdelegate increment_stat(key, increment), to: State, as: :increment

  defdelegate data_migration(), to: DataMigration, as: :populate_hashtags_table

  @reg_name {:global, __MODULE__}

  def whereis, do: GenServer.whereis(@reg_name)

  def start_link(_) do
    case whereis() do
      nil ->
        GenServer.start_link(__MODULE__, nil, name: @reg_name)

      pid ->
        {:ok, pid}
    end
  end

  @impl true
  def init(_) do
    {:ok, nil, {:continue, :init_state}}
  end

  @impl true
  def handle_continue(:init_state, _state) do
    {:ok, _} = State.start_link(nil)

    update_status(:init)

    data_migration = data_migration()
    manual_migrations = Config.get([:instance, :manual_data_migrations], [])

    cond do
      Config.get(:env) == :test ->
        update_status(:noop)

      is_nil(data_migration) ->
        update_status(:halt, "Data migration does not exist.")

      data_migration.state == :manual or data_migration.name in manual_migrations ->
        update_status(:noop, "Data migration is in manual execution state.")

      data_migration.state == :complete ->
        handle_success(data_migration)

      true ->
        send(self(), :migrate_hashtags)
    end

    {:noreply, nil}
  end

  @impl true
  def handle_info(:migrate_hashtags, state) do
    State.clear()

    update_status(:running)
    put_stat(:started_at, NaiveDateTime.utc_now())

    data_migration = data_migration()
    persistent_data = Map.take(data_migration.data, ["max_processed_id"])

    {:ok, data_migration} =
      DataMigration.update(data_migration, %{state: :running, data: persistent_data})

    Logger.info("Starting transferring object embedded hashtags to `hashtags` table...")

    max_processed_id = data_migration.data["max_processed_id"] || 0

    query()
    |> where([object], object.id > ^max_processed_id)
    |> Repo.chunk_stream(100, :batches, timeout: :infinity)
    |> Stream.each(fn objects ->
      object_ids = Enum.map(objects, & &1.id)

      failed_ids =
        objects
        |> Enum.map(&transfer_object_hashtags(&1))
        |> Enum.filter(&(elem(&1, 0) == :error))
        |> Enum.map(&elem(&1, 1))

      for failed_id <- failed_ids do
        _ =
          Repo.query(
            "INSERT INTO data_migration_failed_ids(data_migration_id, record_id) " <>
              "VALUES ($1, $2) ON CONFLICT DO NOTHING;",
            [data_migration.id, failed_id]
          )
      end

      _ =
        Repo.query(
          "DELETE FROM data_migration_failed_ids " <>
            "WHERE data_migration_id = $1 AND record_id = ANY($2)",
          [data_migration.id, object_ids -- failed_ids]
        )

      max_object_id = Enum.at(object_ids, -1)

      put_stat(:max_processed_id, max_object_id)
      increment_stat(:processed_count, length(object_ids))
      increment_stat(:failed_count, length(failed_ids))

      put_stat(
        :records_per_second,
        state()[:processed_count] /
          Enum.max([NaiveDateTime.diff(NaiveDateTime.utc_now(), state()[:started_at]), 1])
      )

      persist_stats(data_migration)

      # A quick and dirty approach to controlling the load this background migration imposes
      sleep_interval = Config.get([:populate_hashtags_table, :sleep_interval_ms], 0)
      Process.sleep(sleep_interval)
    end)
    |> Stream.run()

    with 0 <- failures_count(data_migration.id) do
      _ = delete_non_create_activities_hashtags()

      {:ok, data_migration} = DataMigration.update_state(data_migration, :complete)

      handle_success(data_migration)
    else
      _ ->
        _ = DataMigration.update_state(data_migration, :failed)

        update_status(:failed, "Please check data_migration_failed_ids records.")
    end

    {:noreply, state}
  end

  @hashtags_objects_cleanup_query """
  DELETE FROM hashtags_objects WHERE object_id IN
    (SELECT DISTINCT objects.id FROM objects
      JOIN hashtags_objects ON hashtags_objects.object_id = objects.id LEFT JOIN activities
        ON COALESCE(activities.data->'object'->>'id', activities.data->>'object') =
          (objects.data->>'id')
        AND activities.data->>'type' = 'Create'
      WHERE activities.id IS NULL);
  """

  @hashtags_cleanup_query """
  DELETE FROM hashtags WHERE id IN
    (SELECT hashtags.id FROM hashtags
      LEFT OUTER JOIN hashtags_objects
        ON hashtags_objects.hashtag_id = hashtags.id
      WHERE hashtags_objects.hashtag_id IS NULL);
  """

  def delete_non_create_activities_hashtags do
    {:ok, %{num_rows: hashtags_objects_count}} =
      Repo.query(@hashtags_objects_cleanup_query, [], timeout: :infinity)

    {:ok, %{num_rows: hashtags_count}} =
      Repo.query(@hashtags_cleanup_query, [], timeout: :infinity)

    {:ok, hashtags_objects_count, hashtags_count}
  end

  defp query do
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

  defp transfer_object_hashtags(object) do
    embedded_tags = if Map.has_key?(object, :tag), do: object.tag, else: object.data["tag"]
    hashtags = Object.object_data_hashtags(%{"tag" => embedded_tags})

    if Enum.any?(hashtags) do
      transfer_object_hashtags(object, hashtags)
    else
      {:ok, object.id}
    end
  end

  defp transfer_object_hashtags(object, hashtags) do
    Repo.transaction(fn ->
      with {:ok, hashtag_records} <- Hashtag.get_or_create_by_names(hashtags) do
        maps = Enum.map(hashtag_records, &%{hashtag_id: &1.id, object_id: object.id})
        expected_rows = length(hashtag_records)

        base_error =
          "ERROR when inserting #{expected_rows} hashtags_objects for obj. #{object.id}"

        try do
          with {^expected_rows, _} <- Repo.insert_all("hashtags_objects", maps) do
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

  @doc "Approximate count for current iteration (including processed records count)"
  def count(force \\ false, timeout \\ :infinity) do
    stored_count = state()[:count]

    if stored_count && !force do
      stored_count
    else
      processed_count = state()[:processed_count] || 0
      max_processed_id = data_migration().data["max_processed_id"] || 0
      query = where(query(), [object], object.id > ^max_processed_id)

      count = Repo.aggregate(query, :count, :id, timeout: timeout) + processed_count
      put_stat(:count, count)
      count
    end
  end

  defp persist_stats(data_migration) do
    runner_state = Map.drop(state(), [:status])
    _ = DataMigration.update(data_migration, %{data: runner_state})
  end

  defp handle_success(data_migration) do
    update_status(:complete)

    cond do
      data_migration.feature_lock ->
        :noop

      not is_nil(Config.get([:database, :improved_hashtag_timeline])) ->
        :noop

      true ->
        Config.put([:database, :improved_hashtag_timeline], true)
        :ok
    end
  end

  def failed_objects_query do
    from(o in Object)
    |> join(:inner, [o], dmf in fragment("SELECT * FROM data_migration_failed_ids"),
      on: dmf.record_id == o.id
    )
    |> where([_o, dmf], dmf.data_migration_id == ^data_migration().id)
    |> order_by([o], asc: o.id)
  end

  def failures_count(data_migration_id \\ nil) do
    data_migration_id = data_migration_id || data_migration().id

    with {:ok, %{rows: [[count]]}} <-
           Repo.query(
             "SELECT COUNT(record_id) FROM data_migration_failed_ids WHERE data_migration_id = $1;",
             [data_migration_id]
           ) do
      count
    end
  end

  def retry_failed do
    data_migration = data_migration()

    failed_objects_query()
    |> Repo.chunk_stream(100, :one)
    |> Stream.each(fn object ->
      with {:ok, _} <- transfer_object_hashtags(object) do
        _ =
          Repo.query(
            "DELETE FROM data_migration_failed_ids " <>
              "WHERE data_migration_id = $1 AND record_id = $2",
            [data_migration.id, object.id]
          )
      end
    end)
    |> Stream.run()
  end

  def force_continue do
    send(whereis(), :migrate_hashtags)
  end

  def force_restart do
    {:ok, _} = DataMigration.update(data_migration(), %{state: :pending, data: %{}})
    force_continue()
  end

  def force_complete do
    {:ok, data_migration} = DataMigration.update_state(data_migration(), :complete)

    handle_success(data_migration)
  end

  defp update_status(status, message \\ nil) do
    put_stat(:status, status)
    put_stat(:message, message)
  end
end
