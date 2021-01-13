# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.HashtagsTableMigrator do
  defmodule State do
    use Agent

    @init_state %{}

    def start_link(_) do
      Agent.start_link(fn -> @init_state end, name: __MODULE__)
    end

    def get do
      Agent.get(__MODULE__, & &1)
    end

    def put(key, value) do
      Agent.update(__MODULE__, fn state ->
        Map.put(state, key, value)
      end)
    end

    def increment(key, increment \\ 1) do
      Agent.update(__MODULE__, fn state ->
        updated_value = (state[key] || 0) + increment
        Map.put(state, key, updated_value)
      end)
    end
  end

  use GenServer

  require Logger

  import Ecto.Query

  alias Pleroma.Config
  alias Pleroma.DataMigration
  alias Pleroma.Hashtag
  alias Pleroma.Object
  alias Pleroma.Repo

  defdelegate state(), to: State, as: :get
  defdelegate put_state(key, value), to: State, as: :put
  defdelegate increment_state(key, increment), to: State, as: :increment

  defdelegate data_migration(), to: DataMigration, as: :populate_hashtags_table

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, nil, {:continue, :init_state}}
  end

  @impl true
  def handle_continue(:init_state, _state) do
    {:ok, _} = State.start_link(nil)

    put_state(:status, :init)

    dm = data_migration()

    cond do
      Config.get(:env) == :test ->
        put_state(:status, :noop)

      is_nil(dm) ->
        put_state(:status, :halt)
        put_state(:message, "Data migration does not exist.")

      dm.state == :manual ->
        put_state(:status, :noop)
        put_state(:message, "Data migration is in manual execution state.")

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

    {:ok, data_migration} = DataMigration.update_state(data_migration, :running)
    put_state(:status, :running)

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
      _ = DataMigration.update(data_migration, %{data: %{"max_processed_id" => max_object_id}})

      increment_state(:processed_count, length(object_ids))
      increment_state(:failed_count, length(failed_ids))

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
      put_state(:status, :complete)
      _ = DataMigration.update_state(data_migration, :complete)

      handle_success()
    else
      _ ->
        put_state(:status, :failed)
        put_state(:message, "Please check data_migration_failed_ids records.")
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

  defp handle_success do
    put_state(:status, :complete)

    unless Config.improved_hashtag_timeline() do
      Config.put(Config.improved_hashtag_timeline_path(), true)
    end

    :ok
  end
end
