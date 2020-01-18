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
    # TODO: add support for releases
    start_pleroma()

    {opts, _} =
      OptionParser.parse!(options,
        strict: [env: :string, delete_from_db: :boolean],
        aliases: [d: :delete_from_db]
      )

    with {:active?, true} <-
           {:active?, Pleroma.Config.get([:configurable_from_database])},
         env when is_binary(env) <- opts[:env] || "prod",
         config_path <- config_path(env),
         {:ok, file} <- File.open(config_path, [:write, :utf8]) do
      IO.write(file, config_header())

      ConfigDB
      |> Repo.all()
      |> Enum.each(&write_to_file_with_deletion(&1, file, opts[:delete_from_db]))

      File.close(file)
      System.cmd("mix", ["format", config_path])
    else
      {:active?, false} ->
        shell_info(
          "Migration is not allowed by config. You can change this behavior in instance settings."
        )

      error ->
        shell_info("Error occuried while opening file. #{inspect(error)}")
    end
  end

  defp config_path(env) do
    path =
      if Pleroma.Config.get(:release) do
        :config_path
        |> Pleroma.Config.get()
        |> Path.dirname()
      else
        "config"
      end

    Path.join(path, "#{env}.exported_from_db.secret.exs")
  end

  @spec migrate_to_db(Path.t() | nil) :: any()
  def migrate_to_db(file_path \\ nil) do
    if Pleroma.Config.get([:configurable_from_database]) do
      user_config_file =
        if Pleroma.Config.get(:release),
          do: Pleroma.Config.get(:config_path),
          else: "config/#{Pleroma.Config.get(:env)}.secret.exs"

      config_file = file_path || user_config_file
      do_migrate_to_db(config_file)
    else
      shell_info(
        "Migration is not allowed by config. You can change this behavior in instance settings."
      )
    end
  end

  if Code.ensure_loaded?(Config.Reader) do
    defp config_header, do: "import Config\r\n\r\n"
    defp read_file(config_file), do: Config.Reader.read_imports!(config_file)
  else
    defp config_header, do: "use Mix.Config\r\n\r\n"
    defp read_file(config_file), do: Mix.Config.eval!(config_file)
  end

  defp do_migrate_to_db(config_file) do
    if File.exists?(config_file) do
      {custom_config, _paths} = read_file(config_file)

      custom_config
      |> Keyword.keys()
      |> Enum.each(&create(&1, custom_config[&1]))
    else
      shell_info("To migrate settings, you must define custom settings in #{config_file}.")
    end
  end

  defp create(group, settings) do
    Enum.reject(settings, fn {k, _v} ->
      k in [Pleroma.Repo, Pleroma.Web.Endpoint, :env, :configurable_from_database] or
        (group == :phoenix and k == :serve_endpoints)
    end)
    |> Enum.each(fn {key, value} ->
      key = inspect(key)
      {:ok, _} = ConfigDB.update_or_create(%{group: inspect(group), key: key, value: value})

      shell_info("Settings for key #{key} migrated.")
    end)

    shell_info("Settings for group :#{group} migrated.")
  end

  defp write_to_file_with_deletion(config, file, with_deletion) do
    IO.write(
      file,
      "config #{config.group}, #{config.key}, #{
        inspect(ConfigDB.from_binary(config.value), limit: :infinity)
      }\r\n\r\n"
    )

    if with_deletion do
      {:ok, _} = Repo.delete(config)
      shell_info("#{config.key} deleted from DB.")
    end
  end
end
