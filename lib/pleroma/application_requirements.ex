# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ApplicationRequirements do
  @moduledoc """
  The module represents the collection of validations to runs before start server.
  """

  defmodule VerifyError, do: defexception([:message])

  alias Pleroma.Config
  alias Pleroma.Helpers.MediaHelper

  import Ecto.Query

  require Logger

  @spec verify!() :: :ok | VerifyError.t()
  def verify! do
    :ok
    |> check_system_commands!()
    |> check_confirmation_accounts!()
    |> check_migrations_applied!()
    |> check_welcome_message_config!()
    |> check_rum!()
    |> check_repo_pool_size!()
    |> handle_result()
  end

  defp handle_result(:ok), do: :ok
  defp handle_result({:error, message}), do: raise(VerifyError, message: message)

  defp check_welcome_message_config!(:ok) do
    if Pleroma.Config.get([:welcome, :email, :enabled], false) and
         not Pleroma.Emails.Mailer.enabled?() do
      Logger.warn("""
      To send welcome emails, you need to enable the mailer.
      Welcome emails will NOT be sent with the current config.

      Enable the mailer:
        config :pleroma, Pleroma.Emails.Mailer, enabled: true
      """)
    end

    :ok
  end

  defp check_welcome_message_config!(result), do: result

  # Checks account confirmation email
  #
  def check_confirmation_accounts!(:ok) do
    if Pleroma.Config.get([:instance, :account_activation_required]) &&
         not Pleroma.Emails.Mailer.enabled?() do
      Logger.warn("""
      Account activation is required, but the mailer is disabled.
      Users will NOT be able to confirm their accounts with this config.
      Either disable account activation or enable the mailer.

      Disable account activation:
        config :pleroma, :instance, account_activation_required: false

      Enable the mailer:
        config :pleroma, Pleroma.Emails.Mailer, enabled: true
      """)
    end

    :ok
  end

  def check_confirmation_accounts!(result), do: result

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
              "The following migrations were not applied:\n#{down_migrations_text}" <>
                "If you want to start Pleroma anyway, set\n" <>
                "config :pleroma, :i_am_aware_this_may_cause_data_loss, disable_migration_check: true"
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
          "Use `RUM` index is enabled, but were not applied migrations for it.\n" <>
            "If you want to start Pleroma anyway, set\n" <>
            "config :pleroma, :database, rum_enabled: false\n" <>
            "Otherwise apply the following migrations:\n" <>
            "`mix ecto.migrate --migrations-path priv/repo/optional_migrations/rum_indexing/`"
        )

        {:error, "Unapplied RUM Migrations detected"}

      {false, true} ->
        Logger.error(
          "Detected applied migrations to use `RUM` index, but `RUM` isn't enable in settings.\n" <>
            "If you want to use `RUM`, set\n" <>
            "config :pleroma, :database, rum_enabled: true\n" <>
            "Otherwise roll `RUM` migrations back.\n" <>
            "`mix ecto.rollback --migrations-path priv/repo/optional_migrations/rum_indexing/`"
        )

        {:error, "RUM Migrations detected"}

      _ ->
        :ok
    end
  end

  defp check_system_commands!(:ok) do
    filter_commands_statuses = [
      check_filter(Pleroma.Upload.Filter.Exiftool.StripLocation, "exiftool"),
      check_filter(Pleroma.Upload.Filter.Exiftool.ReadDescription, "exiftool"),
      check_filter(Pleroma.Upload.Filter.Mogrify, "mogrify"),
      check_filter(Pleroma.Upload.Filter.Mogrifun, "mogrify"),
      check_filter(Pleroma.Upload.Filter.AnalyzeMetadata, "mogrify"),
      check_filter(Pleroma.Upload.Filter.AnalyzeMetadata, "convert"),
      check_filter(Pleroma.Upload.Filter.AnalyzeMetadata, "ffprobe")
    ]

    preview_proxy_commands_status =
      if !Config.get([:media_preview_proxy, :enabled]) or
           MediaHelper.missing_dependencies() == [] do
        true
      else
        Logger.error(
          "The following dependencies required by Media preview proxy " <>
            "(which is currently enabled) are not installed: " <>
            inspect(MediaHelper.missing_dependencies())
        )

        false
      end

    if Enum.all?([preview_proxy_commands_status | filter_commands_statuses], & &1) do
      :ok
    else
      {:error,
       "System commands missing. Check logs and see `docs/installation` for more details."}
    end
  end

  defp check_system_commands!(result), do: result

  defp check_repo_pool_size!(:ok) do
    if Pleroma.Config.get([Pleroma.Repo, :pool_size], 10) != 10 and
         not Pleroma.Config.get([:dangerzone, :override_repo_pool_size], false) do
      Logger.error("""
      !!!CONFIG WARNING!!!

      The database pool size has been altered from the recommended value of 10.

      Please revert or ensure your database is tuned appropriately and then set
      `config :pleroma, :dangerzone, override_repo_pool_size: true`.

      If you are experiencing database timeouts, please check the "Optimizing
      your PostgreSQL performance" section in the documentation. If you still
      encounter issues after that, please open an issue on the tracker.
      """)

      {:error, "Repo.pool_size different than recommended value."}
    else
      :ok
    end
  end

  defp check_repo_pool_size!(result), do: result

  defp check_filter(filter, command_required) do
    filters = Config.get([Pleroma.Upload, :filters])

    if filter in filters and not Pleroma.Utils.command_available?(command_required) do
      Logger.error(
        "#{filter} is specified in list of Pleroma.Upload filters, but the " <>
          "#{command_required} command is not found"
      )

      false
    else
      true
    end
  end
end
