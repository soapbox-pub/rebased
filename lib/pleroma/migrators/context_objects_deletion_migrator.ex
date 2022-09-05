# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.ContextObjectsDeletionMigrator do
  defmodule State do
    use Pleroma.Migrators.Support.BaseMigratorState

    @impl Pleroma.Migrators.Support.BaseMigratorState
    defdelegate data_migration(), to: Pleroma.DataMigration, as: :delete_context_objects
  end

  use Pleroma.Migrators.Support.BaseMigrator

  alias Pleroma.DataMigrationFailedId
  alias Pleroma.Migrators.Support.BaseMigrator
  alias Pleroma.Object

  import Ecto.Query

  @doc "This migration removes objects created exclusively for contexts, containing only an `id` field."

  @impl BaseMigrator
  def feature_config_path, do: [:features, :delete_context_objects]

  @impl BaseMigrator
  def fault_rate_allowance, do: Config.get([:delete_context_objects, :fault_rate_allowance], 0)

  @impl BaseMigrator
  def perform do
    data_migration_id = data_migration_id()
    max_processed_id = get_stat(:max_processed_id, 0)

    Logger.info("Deleting context objects from `objects` (from oid: #{max_processed_id})...")

    query()
    |> where([object], object.id > ^max_processed_id)
    |> Repo.chunk_stream(100, :batches, timeout: :infinity)
    |> Stream.each(fn objects ->
      object_ids = Enum.map(objects, & &1.id)

      results = Enum.map(object_ids, &delete_context_object(&1))

      failed_ids =
        results
        |> Enum.filter(&(elem(&1, 0) == :error))
        |> Enum.map(&elem(&1, 1))

      chunk_affected_count =
        results
        |> Enum.filter(&(elem(&1, 0) == :ok))
        |> length()

      for failed_id <- failed_ids do
        _ =
          %DataMigrationFailedId{
            data_migration_id: data_migration_id,
            record_id: failed_id
          }
          |> Repo.insert(on_conflict: :nothing)
      end

      record_ids = object_ids -- failed_ids

      _ =
        DataMigrationFailedId
        |> where(data_migration_id: ^data_migration_id)
        |> where([dmf], dmf.record_id in ^record_ids)
        |> Repo.delete_all()

      max_object_id = Enum.at(object_ids, -1)

      put_stat(:max_processed_id, max_object_id)
      increment_stat(:iteration_processed_count, length(object_ids))
      increment_stat(:processed_count, length(object_ids))
      increment_stat(:failed_count, length(failed_ids))
      increment_stat(:affected_count, chunk_affected_count)
      put_stat(:records_per_second, records_per_second())
      persist_state()

      # A quick and dirty approach to controlling the load this background migration imposes
      sleep_interval = Config.get([:delete_context_objects, :sleep_interval_ms], 0)
      Process.sleep(sleep_interval)
    end)
    |> Stream.run()
  end

  @impl BaseMigrator
  def query do
    # Context objects have no activity type, and only one field, `id`.
    # Only those context objects are without types.
    from(
      object in Object,
      where: fragment("(?)->'type' IS NULL", object.data),
      select: %{
        id: object.id
      }
    )
  end

  @spec delete_context_object(integer()) :: {:ok | :error, integer()}
  defp delete_context_object(id) do
    result =
      %Object{id: id}
      |> Repo.delete()
      |> elem(0)

    {result, id}
  end

  @impl BaseMigrator
  def retry_failed do
    data_migration_id = data_migration_id()

    failed_objects_query()
    |> Repo.chunk_stream(100, :one)
    |> Stream.each(fn %{id: object_id} ->
      with {res, _} when res != :error <- delete_context_object(object_id) do
        _ =
          DataMigrationFailedId
          |> where(data_migration_id: ^data_migration_id)
          |> where(record_id: ^object_id)
          |> Repo.delete_all()
      end
    end)
    |> Stream.run()

    put_stat(:failed_count, failures_count())
    persist_state()

    force_continue()
  end

  defp failed_objects_query do
    from(o in Object)
    |> join(:inner, [o], dmf in DataMigrationFailedId, on: dmf.record_id == o.id)
    |> where([_o, dmf], dmf.data_migration_id == ^data_migration_id())
    |> order_by([o], asc: o.id)
  end
end
