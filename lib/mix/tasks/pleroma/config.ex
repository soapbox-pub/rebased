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
  def run(["migrate_to_db"]) do
    start_pleroma()

    if Pleroma.Config.get([:instance, :dynamic_configuration]) do
      Application.get_all_env(:pleroma)
      |> Enum.reject(fn {k, _v} -> k in [Pleroma.Repo, :env] end)
      |> Enum.each(fn {k, v} ->
        key = to_string(k) |> String.replace("Elixir.", "")

        key =
          if String.starts_with?(key, "Pleroma.") do
            key
          else
            ":" <> key
          end

        {:ok, _} = Config.update_or_create(%{group: "pleroma", key: key, value: v})
        Mix.shell().info("#{key} is migrated.")
      end)

      Mix.shell().info("Settings migrated.")
    else
      Mix.shell().info(
        "Migration is not allowed by config. You can change this behavior in instance settings."
      )
    end
  end

  def run(["migrate_from_db", env, delete?]) do
    start_pleroma()

    delete? = if delete? == "true", do: true, else: false

    if Pleroma.Config.get([:instance, :dynamic_configuration]) do
      config_path = "config/#{env}.exported_from_db.secret.exs"

      {:ok, file} = File.open(config_path, [:write, :utf8])
      IO.write(file, "use Mix.Config\r\n")

      Repo.all(Config)
      |> Enum.each(fn config ->
        IO.write(
          file,
          "config :#{config.group}, #{config.key}, #{inspect(Config.from_binary(config.value))}\r\n\r\n"
        )

        if delete? do
          {:ok, _} = Repo.delete(config)
          Mix.shell().info("#{config.key} deleted from DB.")
        end
      end)

      File.close(file)
      System.cmd("mix", ["format", config_path])
    else
      Mix.shell().info(
        "Migration is not allowed by config. You can change this behavior in instance settings."
      )
    end
  end
end
