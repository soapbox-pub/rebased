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
    check_configdb()
    start_pleroma()
    migrate_to_db()
  end

  def run(["migrate_from_db" | options]) do
    check_configdb()
    start_pleroma()

    {opts, _} =
      OptionParser.parse!(options,
        strict: [env: :string, delete: :boolean],
        aliases: [d: :delete]
      )

    migrate_from_db(opts)
  end

  def run(["dump"]) do
    check_configdb()
    start_pleroma()

    header = config_header()

    settings =
      ConfigDB
      |> Repo.all()
      |> Enum.sort()

    unless settings == [] do
      shell_info("#{header}")

      settings |> Enum.each(&dump(&1))
    else
      shell_error("No settings in ConfigDB.")
    end
  end

  def run(["dump", group, key]) do
    check_configdb()
    start_pleroma()

    group = maybe_atomize(group)
    key = maybe_atomize(key)

    dump_key(group, key)
  end

  def run(["dump", group]) do
    check_configdb()
    start_pleroma()

    group = maybe_atomize(group)

    dump_group(group)
  end

  def run(["groups"]) do
    check_configdb()
    start_pleroma()

    groups =
      ConfigDB
      |> Repo.all()
      |> Enum.map(fn x -> x.group end)
      |> Enum.sort()
      |> Enum.uniq()

    if length(groups) > 0 do
      shell_info("The following configuration groups are set in ConfigDB:\r\n")
      groups |> Enum.each(fn x -> shell_info("-  #{x}") end)
      shell_info("\r\n")
    end
  end

  def run(["reset"]) do
    check_configdb()
    start_pleroma()

    shell_info("The following settings will be permanently removed:")

    ConfigDB
    |> Repo.all()
    |> Enum.sort()
    |> Enum.each(&dump(&1))

    shell_error("\nTHIS CANNOT BE UNDONE!")

    if shell_prompt("Are you sure you want to continue?", "n") in ~w(Yn Y y) do
      Ecto.Adapters.SQL.query!(Repo, "TRUNCATE config;")
      Ecto.Adapters.SQL.query!(Repo, "ALTER SEQUENCE config_id_seq RESTART;")

      shell_info("The ConfigDB settings have been removed from the database.")
    else
      shell_error("No changes made.")
    end
  end

  def run(["delete", group]) do
    check_configdb()
    start_pleroma()

    group = maybe_atomize(group)

    if group_exists?(group) do
      shell_info("The following settings will be removed from ConfigDB:\n")

      dump_group(group)

      if shell_prompt("Are you sure you want to continue?", "n") in ~w(Yn Y y) do
        ConfigDB
        |> Repo.all()
        |> Enum.filter(fn x ->
          if x.group == group do
            x |> delete(true)
          end
        end)
      else
        shell_error("No changes made.")
      end
    else
      shell_error("No settings in ConfigDB for #{inspect(group)}. Aborting.")
    end
  end

  def run(["delete", group, key]) do
    check_configdb()
    start_pleroma()

    group = maybe_atomize(group)
    key = maybe_atomize(key)

    if shell_prompt("Are you sure you want to continue?", "n") in ~w(Yn Y y) do
      ConfigDB
      |> Repo.all()
      |> Enum.filter(fn x ->
        if x.group == group and x.key == key do
          x |> delete(true)
        end
      end)
    else
      shell_error("No changes made.")
    end
  end

  @spec migrate_to_db(Path.t() | nil) :: any()
  def migrate_to_db(file_path \\ nil) do
    with :ok <- Pleroma.Config.DeprecationWarnings.warn() do
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
      _ -> deprecation_error()
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

    shell_info("Settings for group #{inspect(group)} migrated.")
  end

  defp migrate_from_db(opts) do
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

    shell_info(
      "config #{inspect(config.group)}, #{inspect(config.key)} deleted from the ConfigDB."
    )
  end

  defp delete(_config, _), do: :ok

  defp dump(%Pleroma.ConfigDB{} = config) do
    value = inspect(config.value, limit: :infinity)

    shell_info("config #{inspect(config.group)}, #{inspect(config.key)}, #{value}\r\n\r\n")
  end

  defp configdb_not_enabled do
    raise(
      "ConfigDB not enabled. Please check the value of :configurable_from_database in your configuration."
    )
  end

  defp dump_key(group, key) when is_atom(group) and is_atom(key) do
    ConfigDB
    |> Repo.all()
    |> Enum.filter(fn x ->
      if x.group == group && x.key == key do
        x |> dump
      end
    end)
  end

  defp dump_group(group) when is_atom(group) do
    ConfigDB
    |> Repo.all()
    |> Enum.filter(fn x ->
      if x.group == group do
        x |> dump
      end
    end)
  end

  defp group_exists?(group) when is_atom(group) do
    result =
      ConfigDB
      |> Repo.all()
      |> Enum.filter(fn x ->
        if x.group == group do
          x
        end
      end)

    unless result == [] do
      true
    else
      false
    end
  end

  defp maybe_atomize(arg) when is_atom(arg), do: arg

  defp maybe_atomize(arg) when is_binary(arg) do
    chars = String.codepoints(arg)

    if "." in chars do
      :"Elixir.#{arg}"
    else
      String.to_atom(arg)
    end
  end

  defp check_configdb() do
    with true <- Pleroma.Config.get([:configurable_from_database]) do
      :ok
    else
      _ -> configdb_not_enabled()
    end
  end
end
