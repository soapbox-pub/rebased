# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.Support.BaseMigrator do
  @moduledoc """
  Base background migrator functionality.
  """

  @callback perform() :: any()
  @callback retry_failed() :: any()
  @callback feature_config_path() :: list(atom())
  @callback query() :: Ecto.Query.t()
  @callback fault_rate_allowance() :: integer() | float()

  defmacro __using__(_opts) do
    quote do
      use GenServer

      require Logger

      import Ecto.Query

      alias __MODULE__.State
      alias Pleroma.Config
      alias Pleroma.Repo

      @behaviour Pleroma.Migrators.Support.BaseMigrator

      defdelegate data_migration(), to: State
      defdelegate data_migration_id(), to: State
      defdelegate state(), to: State
      defdelegate persist_state(), to: State, as: :persist_to_db
      defdelegate get_stat(key, value \\ nil), to: State, as: :get_data_key
      defdelegate put_stat(key, value), to: State, as: :put_data_key
      defdelegate increment_stat(key, increment), to: State, as: :increment_data_key

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
            send(self(), :perform)
        end

        {:noreply, nil}
      end

      @impl true
      def handle_info(:perform, state) do
        State.reinit()

        update_status(:running)
        put_stat(:iteration_processed_count, 0)
        put_stat(:started_at, NaiveDateTime.utc_now())

        perform()

        fault_rate = fault_rate()
        put_stat(:fault_rate, fault_rate)
        fault_rate_allowance = fault_rate_allowance()

        cond do
          fault_rate == 0 ->
            set_complete()

          is_float(fault_rate) and fault_rate <= fault_rate_allowance ->
            message = """
            Done with fault rate of #{fault_rate} which doesn't exceed #{fault_rate_allowance}.
            Putting data migration to manual fix mode. Try running `#{__MODULE__}.retry_failed/0`.
            """

            Logger.warn("#{__MODULE__}: #{message}")
            update_status(:manual, message)
            on_complete(data_migration())

          true ->
            message = "Too many failures. Try running `#{__MODULE__}.retry_failed/0`."
            Logger.error("#{__MODULE__}: #{message}")
            update_status(:failed, message)
        end

        persist_state()
        {:noreply, state}
      end

      defp on_complete(data_migration) do
        if data_migration.feature_lock || feature_state() == :disabled do
          Logger.warn(
            "#{__MODULE__}: migration complete but feature is locked; consider enabling."
          )

          :noop
        else
          Config.put(feature_config_path(), :enabled)
          :ok
        end
      end

      @doc "Approximate count for current iteration (including processed records count)"
      def count(force \\ false, timeout \\ :infinity) do
        stored_count = get_stat(:count)

        if stored_count && !force do
          stored_count
        else
          processed_count = get_stat(:processed_count, 0)
          max_processed_id = get_stat(:max_processed_id, 0)
          query = where(query(), [entity], entity.id > ^max_processed_id)

          count = Repo.aggregate(query, :count, :id, timeout: timeout) + processed_count
          put_stat(:count, count)
          persist_state()

          count
        end
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

      def feature_state, do: Config.get(feature_config_path())

      def force_continue do
        send(whereis(), :perform)
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

      defp fault_rate do
        with failures_count when is_integer(failures_count) <- failures_count() do
          failures_count / Enum.max([get_stat(:affected_count, 0), 1])
        else
          _ -> :error
        end
      end

      defp records_per_second do
        get_stat(:iteration_processed_count, 0) / Enum.max([running_time(), 1])
      end

      defp running_time do
        NaiveDateTime.diff(
          NaiveDateTime.utc_now(),
          get_stat(:started_at, NaiveDateTime.utc_now())
        )
      end
    end
  end
end
