# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Frontend do
  use Mix.Task

  import Mix.Pleroma

  @shortdoc "Manages bundled Pleroma frontends"

  # @moduledoc File.read!("docs/administration/CLI_tasks/frontend.md")

  def run(["install", "none" | _args]) do
    shell_info("Skipping frontend installation because none was requested")
    "none"
  end

  def run(["install", frontend | args]) do
    log_level = Logger.level()
    Logger.configure(level: :warn)
    start_pleroma()

    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          ref: :string,
          static_dir: :string,
          build_url: :string
        ]
      )

    instance_static_dir =
      with nil <- options[:static_dir] do
        Pleroma.Config.get!([:instance, :static_dir])
      end

    cmd_frontend_info = %{
      "name" => frontend,
      "ref" => options[:ref],
      "build_url" => options[:build_url]
    }

    config_frontend_info = Pleroma.Config.get([:frontends, :available, frontend], %{})

    frontend_info =
      Map.merge(config_frontend_info, cmd_frontend_info, fn _key, config, cmd ->
        # This only overrides things that are actually set
        cmd || config
      end)

    ref = frontend_info["ref"]

    unless ref do
      raise "No ref given or configured"
    end

    dest =
      Path.join([
        instance_static_dir,
        "frontends",
        frontend,
        ref
      ])

    fe_label = "#{frontend} (#{ref})"

    shell_info("Downloading pre-built bundle for #{fe_label}")
    tmp_dir = Path.join(dest, "tmp")

    with {_, :ok} <- {:download, download_build(frontend_info, tmp_dir)},
         shell_info("Installing #{fe_label} to #{dest}"),
         :ok <- install_frontend(frontend_info, tmp_dir, dest) do
      File.rm_rf!(tmp_dir)
      shell_info("Frontend #{fe_label} installed to #{dest}")

      Logger.configure(level: log_level)
    else
      {:download, _} ->
        shell_info("Could not download the frontend")

      _e ->
        shell_info("Could not install the frontend")
    end
  end

  defp download_build(frontend_info, dest) do
    url = String.replace(frontend_info["build_url"], "${ref}", frontend_info["ref"])

    with {:ok, %{status: 200, body: zip_body}} <-
           Pleroma.HTTP.get(url, [], timeout: 120_000, recv_timeout: 120_000),
         {:ok, unzipped} <- :zip.unzip(zip_body, [:memory]) do
      File.rm_rf!(dest)
      File.mkdir_p!(dest)

      Enum.each(unzipped, fn {filename, data} ->
        path = filename

        new_file_path = Path.join(dest, path)

        new_file_path
        |> Path.dirname()
        |> File.mkdir_p!()

        File.write!(new_file_path, data)
      end)

      :ok
    else
      e -> {:error, e}
    end
  end

  defp install_frontend(frontend_info, source, dest) do
    from = frontend_info["build_dir"] || "dist"
    File.mkdir_p!(dest)
    File.cp_r!(Path.join([source, from]), dest)
    :ok
  end
end
