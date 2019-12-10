# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Config do
  use Mix.Task
  import Mix.Pleroma
  alias Pleroma.Repo
  alias Pleroma.Web.AdminAPI.Config
  @shortdoc "Manages the location of the config"
  @moduledoc File.read!("docs/administration/CLI_tasks/config.md")

  @groups [
    :pleroma,
    :logger,
    :quack,
    :mime,
    :tesla,
    :phoenix,
    :cors_plug,
    :auto_linker,
    :esshd,
    :ueberauth,
    :prometheus,
    :http_signatures,
    :web_push_encryption,
    :joken
  ]

  def run(["migrate_to_db"]) do
    start_pleroma()

    if Pleroma.Config.get([:instance, :dynamic_configuration]) do
      Enum.each(@groups, &load_and_create(&1))
    else
      Mix.shell().info(
        "Migration is not allowed by config. You can change this behavior in instance settings."
      )
    end
  end

  def run(["migrate_from_db" | options]) do
    start_pleroma()

    {opts, _} =
      OptionParser.parse!(options,
        strict: [env: :string, delete_from_db: :boolean],
        aliases: [d: :delete_from_db]
      )

    with {:active?, true} <- {:active?, Pleroma.Config.get([:instance, :dynamic_configuration])},
         env_path when is_binary(env_path) <- opts[:env],
         config_path <- "config/#{env_path}.exported_from_db.secret.exs",
         {:ok, file} <- File.open(config_path, [:write, :utf8]) do
      IO.write(file, "use Mix.Config\r\n")

      Config
      |> Repo.all()
      |> Enum.each(&write_to_file_with_deletion(&1, file, opts[:delete_from_db]))

      File.close(file)
      System.cmd("mix", ["format", config_path])
    else
      {:active?, false} ->
        Mix.shell().info(
          "migration is not allowed by config. You can change this behavior in instance settings."
        )

      error ->
        Mix.shell().info("error occuried while opening file. #{inspect(error)}")
    end
  end

  defp load_and_create(group) do
    group
    |> Application.get_all_env()
    |> Enum.reject(fn {k, _v} ->
      k in [Pleroma.Repo, :env] or (group == :phoenix and k == :serve_endpoints)
    end)
    |> Enum.each(fn {key, value} ->
      key = inspect(key)
      {:ok, _} = Config.update_or_create(%{group: inspect(group), key: key, value: value})

      Mix.shell().info("settings for key #{key} migrated.")
    end)

    Mix.shell().info("settings for group :#{group} migrated.")
  end

  defp write_to_file_with_deletion(config, file, with_deletion) do
    IO.write(
      file,
      "config #{config.group}, #{config.key}, #{
        inspect(Config.from_binary(config.value), limit: :infinity)
      }\r\n\r\n"
    )

    if with_deletion do
      {:ok, _} = Repo.delete(config)
      Mix.shell().info("#{config.key} deleted from DB.")
    end
  end
end
