# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.Support.BaseMigratorState do
  @moduledoc """
  Base background migrator state functionality.
  """

  @callback data_migration() :: Pleroma.DataMigration.t()

  defmacro __using__(_opts) do
    quote do
      use Agent

      alias Pleroma.DataMigration

      @behaviour Pleroma.Migrators.Support.BaseMigratorState
      @reg_name {:global, __MODULE__}

      def start_link(_) do
        Agent.start_link(fn -> load_state_from_db() end, name: @reg_name)
      end

      def data_migration, do: raise("data_migration/0 is not implemented")
      defoverridable data_migration: 0

      defp load_state_from_db do
        data_migration = data_migration()

        data =
          if data_migration do
            Map.new(data_migration.data, fn {k, v} -> {String.to_atom(k), v} end)
          else
            %{}
          end

        %{
          data_migration_id: data_migration && data_migration.id,
          data: data
        }
      end

      def persist_to_db do
        %{data_migration_id: data_migration_id, data: data} = state()

        if data_migration_id do
          DataMigration.update_one_by_id(data_migration_id, data: data)
        else
          {:error, :nil_data_migration_id}
        end
      end

      def reset do
        %{data_migration_id: data_migration_id} = state()

        with false <- is_nil(data_migration_id),
             :ok <-
               DataMigration.update_one_by_id(data_migration_id,
                 state: :pending,
                 data: %{}
               ) do
          reinit()
        else
          true -> {:error, :nil_data_migration_id}
          e -> e
        end
      end

      def reinit do
        Agent.update(@reg_name, fn _state -> load_state_from_db() end)
      end

      def state do
        Agent.get(@reg_name, & &1)
      end

      def get_data_key(key, default \\ nil) do
        get_in(state(), [:data, key]) || default
      end

      def put_data_key(key, value) do
        _ = persist_non_data_change(key, value)

        Agent.update(@reg_name, fn state ->
          put_in(state, [:data, key], value)
        end)
      end

      def increment_data_key(key, increment \\ 1) do
        Agent.update(@reg_name, fn state ->
          initial_value = get_in(state, [:data, key]) || 0
          updated_value = initial_value + increment
          put_in(state, [:data, key], updated_value)
        end)
      end

      defp persist_non_data_change(:state, value) do
        with true <- get_data_key(:state) != value,
             true <- value in Pleroma.DataMigration.State.__valid_values__(),
             %{data_migration_id: data_migration_id} when not is_nil(data_migration_id) <-
               state() do
          DataMigration.update_one_by_id(data_migration_id, state: value)
        else
          false -> :ok
          _ -> {:error, :nil_data_migration_id}
        end
      end

      defp persist_non_data_change(_, _) do
        nil
      end

      def data_migration_id, do: Map.get(state(), :data_migration_id)
    end
  end
end
