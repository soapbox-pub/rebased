defmodule Mix.Tasks.Pleroma.Config do
  use Mix.Task
  import Mix.Pleroma
  alias Pleroma.Repo
  alias Pleroma.Web.AdminAPI.Config
  @shortdoc "Manages the location of the config"
  @moduledoc """
  Manages the location of the config.

  ## Transfers config from file to DB.

      mix pleroma.config migrate_to_db

  ## Transfers config from DB to file.

      mix pleroma.config migrate_from_db ENV
  """

  def run(["migrate_to_db"]) do
    start_pleroma()

    if Pleroma.Config.get([:instance, :dynamic_configuration]) do
      Application.get_all_env(:pleroma)
      |> Enum.reject(fn {k, _v} -> k in [Pleroma.Repo, :env] end)
      |> Enum.each(fn {k, v} ->
        key = to_string(k) |> String.replace("Elixir.", "")
        {:ok, _} = Config.update_or_create(%{key: key, value: v})
        Mix.shell().info("#{key} is migrated.")
      end)

      Mix.shell().info("Settings migrated.")
    else
      Mix.shell().info(
        "Migration is not allowed by config. You can change this behavior in instance settings."
      )
    end
  end

  def run(["migrate_from_db", env]) do
    start_pleroma()

    if Pleroma.Config.get([:instance, :dynamic_configuration]) do
      config_path = "config/#{env}.exported_from_db.secret.exs"

      {:ok, file} = File.open(config_path, [:write])
      IO.write(file, "use Mix.Config\r\n")

      Repo.all(Config)
      |> Enum.each(fn config ->
        mark = if String.starts_with?(config.key, "Pleroma."), do: ",", else: ":"

        IO.write(
          file,
          "config :pleroma, #{config.key}#{mark} #{inspect(Config.from_binary(config.value))}\r\n"
        )

        {:ok, _} = Repo.delete(config)
        Mix.shell().info("#{config.key} deleted from DB.")
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
