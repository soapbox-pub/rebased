# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Config do
  use Mix.Task

  import Mix.Pleroma

  alias Pleroma.ConfigDB
  alias Pleroma.Repo

  @shortdoc "Manages the location of the config"
  @moduledoc File.read!("docs/administration/CLI_tasks/config.md")

  def run(["migrate_to_db"]) do
    start_pleroma()
    migrate_to_db()
  end

  def run(["migrate_from_db" | options]) do
    start_pleroma()

    {opts, _} =
      OptionParser.parse!(options,
        strict: [env: :string, delete: :boolean],
        aliases: [d: :delete]
      )

    migrate_from_db(opts)
  end

  def run(["dump"]) do
    with true <- Pleroma.Config.get([:configurable_from_database]) do
      start_pleroma()

      header = config_header()

      shell_info("#{header}")

      ConfigDB
      |> Repo.all()
      |> Enum.each(&dump(&1))
    else
      _ -> configdb_not_enabled()
    end
  end

  def run(["dump" | dbkey]) do
    with true <- Pleroma.Config.get([:configurable_from_database]) do
      start_pleroma()

      dbkey = dbkey |> List.first() |> String.to_atom()

      ConfigDB
      |> Repo.all()
      |> Enum.filter(fn x ->
        if x.key == dbkey do
          x |> dump
        end
      end)
    else
      _ -> configdb_not_enabled()
    end
  end

  def run(["keylist"]) do
    with true <- Pleroma.Config.get([:configurable_from_database]) do
      start_pleroma()

      keys =
        ConfigDB
        |> Repo.all()
        |> Enum.map(fn x -> x.key end)

      if length(keys) > 0 do
        shell_info("The following configuration keys are set in ConfigDB:\r\n")
        keys |> Enum.each(fn x -> shell_info("-  #{x}") end)
        shell_info("\r\n")
      end
    else
      _ -> configdb_not_enabled()
    end
  end

  def run(["reset"]) do
    with true <- Pleroma.Config.get([:configurable_from_database]) do
      start_pleroma()

      Ecto.Adapters.SQL.query!(Repo, "TRUNCATE config;")
      Ecto.Adapters.SQL.query!(Repo, "ALTER SEQUENCE config_id_seq RESTART;")

      shell_info("The ConfigDB settings have been removed from the database.")
    else
      _ -> configdb_not_enabled()
    end
  end

  def run(["keydel" | dbkey]) do
    unless [] == dbkey do
      with true <- Pleroma.Config.get([:configurable_from_database]) do
        start_pleroma()

        dbkey = dbkey |> List.first() |> String.to_atom()

        ConfigDB
        |> Repo.all()
        |> Enum.filter(fn x ->
          if x.key == dbkey do
            x |> delete(true)
          end
        end)
      else
        _ -> configdb_not_enabled()
      end
    else
      shell_error(
        "You must provide a key to delete. Use the keylist command to get a list of valid keys."
      )
    end
  end

  @spec migrate_to_db(Path.t() | nil) :: any()
  def migrate_to_db(file_path \\ nil) do
    with true <- Pleroma.Config.get([:configurable_from_database]),
         :ok <- Pleroma.Config.DeprecationWarnings.warn() do
      config_file =
        if file_path do
          file_path
        else
          if Pleroma.Config.get(:release) do
            Pleroma.Config.get(:config_path)
          else
            "config/#{Pleroma.Config.get(:env)}.secret.exs"
          end
        end

      do_migrate_to_db(config_file)
    else
      :error -> deprecation_error()
      _ -> migration_error()
    end
  end

  defp do_migrate_to_db(config_file) do
    if File.exists?(config_file) do
      shell_info("Migrating settings from file: #{Path.expand(config_file)}")
      Ecto.Adapters.SQL.query!(Repo, "TRUNCATE config;")
      Ecto.Adapters.SQL.query!(Repo, "ALTER SEQUENCE config_id_seq RESTART;")

      custom_config =
        config_file
        |> read_file()
        |> elem(0)

      custom_config
      |> Keyword.keys()
      |> Enum.each(&create(&1, custom_config))
    else
      shell_info("To migrate settings, you must define custom settings in #{config_file}.")
    end
  end

  defp create(group, settings) do
    group
    |> Pleroma.Config.Loader.filter_group(settings)
    |> Enum.each(fn {key, value} ->
      {:ok, _} = ConfigDB.update_or_create(%{group: group, key: key, value: value})

      shell_info("Settings for key #{key} migrated.")
    end)

    shell_info("Settings for group :#{group} migrated.")
  end

  defp migrate_from_db(opts) do
    if Pleroma.Config.get([:configurable_from_database]) do
      env = opts[:env] || Pleroma.Config.get(:env)

      config_path =
        if Pleroma.Config.get(:release) do
          :config_path
          |> Pleroma.Config.get()
          |> Path.dirname()
        else
          "config"
        end
        |> Path.join("#{env}.exported_from_db.secret.exs")

      file = File.open!(config_path, [:write, :utf8])

      IO.write(file, config_header())

      ConfigDB
      |> Repo.all()
      |> Enum.each(&write_and_delete(&1, file, opts[:delete]))

      :ok = File.close(file)
      System.cmd("mix", ["format", config_path])

      shell_info(
        "Database configuration settings have been exported to config/#{env}.exported_from_db.secret.exs"
      )
    else
      migration_error()
    end
  end

  defp migration_error do
    shell_error(
      "Migration is not allowed in config. You can change this behavior by setting `config :pleroma, configurable_from_database: true`"
    )
  end

  defp deprecation_error do
    shell_error("Migration is not allowed until all deprecation warnings have been resolved.")
  end

  if Code.ensure_loaded?(Config.Reader) do
    defp config_header, do: "import Config\r\n\r\n"
    defp read_file(config_file), do: Config.Reader.read_imports!(config_file)
  else
    defp config_header, do: "use Mix.Config\r\n\r\n"
    defp read_file(config_file), do: Mix.Config.eval!(config_file)
  end

  defp write_and_delete(config, file, delete?) do
    config
    |> write(file)
    |> delete(delete?)
  end

  defp write(config, file) do
    value = inspect(config.value, limit: :infinity)

    IO.write(file, "config #{inspect(config.group)}, #{inspect(config.key)}, #{value}\r\n\r\n")

    config
  end

  defp delete(config, true) do
    {:ok, _} = Repo.delete(config)
    shell_info("#{config.key} deleted from the ConfigDB.")
  end

  defp delete(_config, _), do: :ok

  defp dump(%Pleroma.ConfigDB{} = config) do
    value = inspect(config.value, limit: :infinity)

    shell_info("config #{inspect(config.group)}, #{inspect(config.key)}, #{value}\r\n\r\n")
  end

  defp configdb_not_enabled do
    shell_error(
      "ConfigDB not enabled. Please check the value of :configurable_from_database in your configuration."
    )
  end
end
