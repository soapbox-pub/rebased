# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.HashtagsTableMigrator do
  use GenServer

  require Logger

  import Ecto.Query

  alias __MODULE__.State
  alias Pleroma.Config
  alias Pleroma.Hashtag
  alias Pleroma.Object
  alias Pleroma.Repo

  defdelegate data_migration(), to: Pleroma.DataMigration, as: :populate_hashtags_table
  defdelegate data_migration_id(), to: State

  defdelegate state(), to: State
  defdelegate persist_state(), to: State, as: :persist_to_db
  defdelegate get_stat(key, value \\ nil), to: State, as: :get_data_key
  defdelegate put_stat(key, value), to: State, as: :put_data_key
  defdelegate increment_stat(key, increment), to: State, as: :increment_data_key

  @feature_config_path [:database, :improved_hashtag_timeline]
  @reg_name {:global, __MODULE__}

  def whereis, do: GenServer.whereis(@reg_name)

  def feature_state, do: Config.get(@feature_config_path)

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

    data_migration = data_migration()
    manual_migrations = Config.get([:instance, :manual_data_migrations], [])

    cond do
      Config.get(:env) == :test ->
        update_status(:noop)

      is_nil(data_migration) ->
        message = "Data migration does not exist."
        update_status(:failed, message)
        Logger.error("#{__MODULE__}: #{message}")

      data_migration.state == :manual or data_migration.name in manual_migrations ->
        message = "Data migration is in manual execution or manual fix mode."
        update_status(:manual, message)
        Logger.warn("#{__MODULE__}: #{message}")

      data_migration.state == :complete ->
        on_complete(data_migration)

      true ->
        send(self(), :migrate_hashtags)
    end

    {:noreply, nil}
  end

  @impl true
  def handle_info(:migrate_hashtags, state) do
    State.reinit()

    update_status(:running)
    put_stat(:started_at, NaiveDateTime.utc_now())

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

      # Count of objects with hashtags (`{:noop, id}` is returned for objects having other AS2 tags)
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

    fault_rate = fault_rate()
    put_stat(:fault_rate, fault_rate)
    fault_rate_allowance = Config.get([:populate_hashtags_table, :fault_rate_allowance], 0)

    cond do
      fault_rate == 0 ->
        set_complete()

      is_float(fault_rate) and fault_rate <= fault_rate_allowance ->
        message = """
        Done with fault rate of #{fault_rate} which doesn't exceed #{fault_rate_allowance}.
        Putting data migration to manual fix mode. Check `retry_failed/0`.
        """

        Logger.warn("#{__MODULE__}: #{message}")
        update_status(:manual, message)
        on_complete(data_migration())

      true ->
        message = "Too many failures. Check data_migration_failed_ids records / `retry_failed/0`."
        Logger.error("#{__MODULE__}: #{message}")
        update_status(:failed, message)
    end

    persist_state()
    {:noreply, state}
  end

  def fault_rate do
    with failures_count when is_integer(failures_count) <- failures_count() do
      failures_count / Enum.max([get_stat(:affected_count, 0), 1])
    else
      _ -> :error
    end
  end

  defp records_per_second do
    get_stat(:processed_count, 0) / Enum.max([running_time(), 1])
  end

  defp running_time do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), get_stat(:started_at, NaiveDateTime.utc_now()))
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

  @doc """
  Deletes `hashtags_objects` for legacy objects not asoociated with Create activity.
  Also deletes unreferenced `hashtags` records (might occur after deletion of `hashtags_objects`).
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

  @doc "Approximate count for current iteration (including processed records count)"
  def count(force \\ false, timeout \\ :infinity) do
    stored_count = get_stat(:count)

    if stored_count && !force do
      stored_count
    else
      processed_count = get_stat(:processed_count, 0)
      max_processed_id = get_stat(:max_processed_id, 0)
      query = where(query(), [object], object.id > ^max_processed_id)

      count = Repo.aggregate(query, :count, :id, timeout: timeout) + processed_count
      put_stat(:count, count)
      persist_state()

      count
    end
  end

  defp on_complete(data_migration) do
    cond do
      data_migration.feature_lock ->
        :noop

      not is_nil(feature_state()) ->
        :noop

      true ->
        Config.put(@feature_config_path, true)
        :ok
    end
  end

  def failed_objects_query do
    from(o in Object)
    |> join(:inner, [o], dmf in fragment("SELECT * FROM data_migration_failed_ids"),
      on: dmf.record_id == o.id
    )
    |> where([_o, dmf], dmf.data_migration_id == ^data_migration_id())
    |> order_by([o], asc: o.id)
  end

  def failures_count do
    with {:ok, %{rows: [[count]]}} <-
           Repo.query(
             "SELECT COUNT(record_id) FROM data_migration_failed_ids WHERE data_migration_id = $1;",
             [data_migration_id()]
           ) do
      count
    end
  end

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

  def force_continue do
    send(whereis(), :migrate_hashtags)
  end

  def force_restart do
    :ok = State.reset()
    force_continue()
  end

  def set_complete do
    update_status(:complete)
    persist_state()
    on_complete(data_migration())
  end

  defp update_status(status, message \\ nil) do
    put_stat(:state, status)
    put_stat(:message, message)
  end
end
