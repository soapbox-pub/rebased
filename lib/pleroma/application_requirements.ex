# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ApplicationRequirements do
  @moduledoc """
  The module represents the collection of validations to runs before start server.
  """

  defmodule VerifyError, do: defexception([:message])

  import Ecto.Query

  require Logger

  @spec verify!() :: :ok | VerifyError.t()
  def verify! do
    :ok
    |> check_migrations_applied!()
    |> check_rum!()
    |> handle_result()
  end

  defp handle_result(:ok), do: :ok
  defp handle_result({:error, message}), do: raise(VerifyError, message: message)

  # Checks for pending migrations.
  #
  def check_migrations_applied!(:ok) do
    unless Pleroma.Config.get(
             [:i_am_aware_this_may_cause_data_loss, :disable_migration_check],
             false
           ) do
      {_, res, _} =
        Ecto.Migrator.with_repo(Pleroma.Repo, fn repo ->
          down_migrations =
            Ecto.Migrator.migrations(repo)
            |> Enum.reject(fn
              {:up, _, _} -> true
              {:down, _, _} -> false
            end)

          if length(down_migrations) > 0 do
            down_migrations_text =
              Enum.map(down_migrations, fn {:down, id, name} -> "- #{name} (#{id})\n" end)

            Logger.error(
              "The following migrations were not applied:\n#{down_migrations_text}If you want to start Pleroma anyway, set\nconfig :pleroma, :i_am_aware_this_may_cause_data_loss, disable_migration_check: true"
            )

            {:error, "Unapplied Migrations detected"}
          else
            :ok
          end
        end)

      res
    else
      :ok
    end
  end

  def check_migrations_applied!(result), do: result

  # Checks for settings of RUM indexes.
  #
  defp check_rum!(:ok) do
    {_, res, _} =
      Ecto.Migrator.with_repo(Pleroma.Repo, fn repo ->
        migrate =
          from(o in "columns",
            where: o.table_name == "objects",
            where: o.column_name == "fts_content"
          )
          |> repo.exists?(prefix: "information_schema")

        setting = Pleroma.Config.get([:database, :rum_enabled], false)

        do_check_rum!(setting, migrate)
      end)

    res
  end

  defp check_rum!(result), do: result

  defp do_check_rum!(setting, migrate) do
    case {setting, migrate} do
      {true, false} ->
        Logger.error(
          "Use `RUM` index is enabled, but were not applied migrations for it.\nIf you want to start Pleroma anyway, set\nconfig :pleroma, :database, rum_enabled: false\nOtherwise apply the following migrations:\n`mix ecto.migrate --migrations-path priv/repo/optional_migrations/rum_indexing/`"
        )

        {:error, "Unapplied RUM Migrations detected"}

      {false, true} ->
        Logger.error(
          "Detected applied migrations to use `RUM` index, but `RUM` isn't enable in settings.\nIf you want to use `RUM`, set\nconfig :pleroma, :database, rum_enabled: true\nOtherwise roll `RUM` migrations back.\n`mix ecto.rollback --migrations-path priv/repo/optional_migrations/rum_indexing/`"
        )

        {:error, "RUM Migrations detected"}

      _ ->
        :ok
    end
  end
end
