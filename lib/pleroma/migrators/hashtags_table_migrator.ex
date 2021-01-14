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

    put_stat(:status, :init)

    dm = data_migration()
    manual_migrations = Config.get([:instance, :manual_data_migrations], [])

    cond do
      Config.get(:env) == :test ->
        put_stat(:status, :noop)

      is_nil(dm) ->
        put_stat(:status, :halt)
        put_stat(:message, "Data migration does not exist.")

      dm.state == :manual or dm.name in manual_migrations ->
        put_stat(:status, :noop)
        put_stat(:message, "Data migration is in manual execution state.")

      dm.state == :complete ->
        handle_success()

      true ->
        send(self(), :migrate_hashtags)
    end

    {:noreply, nil}
  end

  @impl true
  def handle_info(:migrate_hashtags, state) do
    data_migration = data_migration()

    persistent_data = Map.take(data_migration.data, ["max_processed_id"])

    {:ok, data_migration} =
      DataMigration.update(data_migration, %{state: :running, data: persistent_data})

    put_stat(:status, :running)

    Logger.info("Starting transferring object embedded hashtags to `hashtags` table...")

    max_processed_id = data_migration.data["max_processed_id"] || 0

    # Note: most objects have Mention-type AS2 tags and no hashtags (but we can't filter them out)
    from(
      object in Object,
      left_join: hashtag in assoc(object, :hashtags),
      where: object.id > ^max_processed_id,
      where: is_nil(hashtag.id),
      where:
        fragment("(?)->'tag' IS NOT NULL AND (?)->'tag' != '[]'::jsonb", object.data, object.data),
      select: %{
        id: object.id,
        tag: fragment("(?)->'tag'", object.data)
      }
    )
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
          "DELETE FROM data_migration_failed_ids WHERE id = ANY($1)",
          [object_ids -- failed_ids]
        )

      max_object_id = Enum.at(object_ids, -1)

      put_stat(:max_processed_id, max_object_id)
      increment_stat(:processed_count, length(object_ids))
      increment_stat(:failed_count, length(failed_ids))

      persist_stats(data_migration)

      # A quick and dirty approach to controlling the load this background migration imposes
      sleep_interval = Config.get([:populate_hashtags_table, :sleep_interval_ms], 0)
      Process.sleep(sleep_interval)
    end)
    |> Stream.run()

    with {:ok, %{rows: [[0]]}} <-
           Repo.query(
             "SELECT COUNT(record_id) FROM data_migration_failed_ids WHERE data_migration_id = $1;",
             [data_migration.id]
           ) do
      _ = DataMigration.update_state(data_migration, :complete)

      handle_success()
    else
      _ ->
        _ = DataMigration.update_state(data_migration, :failed)

        put_stat(:status, :failed)
        put_stat(:message, "Please check data_migration_failed_ids records.")
    end

    {:noreply, state}
  end

  defp transfer_object_hashtags(object) do
    hashtags = Object.object_data_hashtags(%{"tag" => object.tag})

    Repo.transaction(fn ->
      with {:ok, hashtag_records} <- Hashtag.get_or_create_by_names(hashtags) do
        for hashtag_record <- hashtag_records do
          with {:ok, _} <-
                 Repo.query(
                   "insert into hashtags_objects(hashtag_id, object_id) values ($1, $2);",
                   [hashtag_record.id, object.id]
                 ) do
            nil
          else
            {:error, e} ->
              error =
                "ERROR: could not link object #{object.id} and hashtag " <>
                  "#{hashtag_record.id}: #{inspect(e)}"

              Logger.error(error)
              Repo.rollback(object.id)
          end
        end

        object.id
      else
        e ->
          error = "ERROR: could not create hashtags for object #{object.id}: #{inspect(e)}"
          Logger.error(error)
          Repo.rollback(object.id)
      end
    end)
  end

  defp persist_stats(data_migration) do
    runner_state = Map.drop(state(), [:status])
    _ = DataMigration.update(data_migration, %{data: runner_state})
  end

  defp handle_success do
    put_stat(:status, :complete)

    unless Config.improved_hashtag_timeline() do
      Config.put(Config.improved_hashtag_timeline_path(), true)
    end

    :ok
  end

  def force_continue do
    send(whereis(), :migrate_hashtags)
  end

  def force_restart do
    {:ok, _} = DataMigration.update(data_migration(), %{state: :pending, data: %{}})
    force_continue()
  end
end
