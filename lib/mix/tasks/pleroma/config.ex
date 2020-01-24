# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
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

  @spec migrate_to_db(Path.t() | nil) :: any()
  def migrate_to_db(file_path \\ nil) do
    if Pleroma.Config.get([:configurable_from_database]) do
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
      migration_error()
    end
  end

  defp do_migrate_to_db(config_file) do
    if File.exists?(config_file) do
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
      key = inspect(key)
      {:ok, _} = ConfigDB.update_or_create(%{group: inspect(group), key: key, value: value})

      shell_info("Settings for key #{key} migrated.")
    end)

    shell_info("Settings for group :#{group} migrated.")
  end

  defp migrate_from_db(opts) do
    if Pleroma.Config.get([:configurable_from_database]) do
      env = opts[:env] || "prod"

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
    else
      migration_error()
    end
  end

  defp migration_error do
    shell_error(
      "Migration is not allowed in config. You can change this behavior by setting `configurable_from_database` to true."
    )
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
    value =
      config.value
      |> ConfigDB.from_binary()
      |> inspect(limit: :infinity)

    IO.write(file, "config #{config.group}, #{config.key}, #{value}\r\n\r\n")

    config
  end

  defp delete(config, true) do
    {:ok, _} = Repo.delete(config)
    shell_info("#{config.key} deleted from DB.")
  end

  defp delete(_config, _), do: :ok
end
