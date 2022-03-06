# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Frontend do
  alias Pleroma.Config

  require Logger

  def install(name, opts \\ []) do
    frontend_info = %{
      "ref" => opts[:ref],
      "build_url" => opts[:build_url],
      "build_dir" => opts[:build_dir]
    }

    frontend_info =
      [:frontends, :available, name]
      |> Config.get(%{})
      |> Map.merge(frontend_info, fn _key, config, cmd ->
        # This only overrides things that are actually set
        cmd || config
      end)

    ref = frontend_info["ref"]

    unless ref do
      raise "No ref given or configured"
    end

    dest = Path.join([dir(), name, ref])

    label = "#{name} (#{ref})"
    tmp_dir = Path.join(dir(), "tmp")

    with {_, :ok} <-
           {:download_or_unzip, download_or_unzip(frontend_info, tmp_dir, opts[:file])},
         Logger.info("Installing #{label} to #{dest}"),
         :ok <- install_frontend(frontend_info, tmp_dir, dest) do
      File.rm_rf!(tmp_dir)
      Logger.info("Frontend #{label} installed to #{dest}")
    else
      {:download_or_unzip, _} ->
        Logger.info("Could not download or unzip the frontend")
        {:error, "Could not download or unzip the frontend"}

      _e ->
        Logger.info("Could not install the frontend")
        {:error, "Could not install the frontend"}
    end
  end

  def dir(opts \\ []) do
    if is_nil(opts[:static_dir]) do
      Pleroma.Config.get!([:instance, :static_dir])
    else
      opts[:static_dir]
    end
    |> Path.join("frontends")
  end

  defp download_or_unzip(frontend_info, temp_dir, nil),
    do: download_build(frontend_info, temp_dir)

  defp download_or_unzip(_frontend_info, temp_dir, file) do
    with {:ok, zip} <- File.read(Path.expand(file)) do
      unzip(zip, temp_dir)
    end
  end

  def unzip(zip, dest) do
    with {:ok, unzipped} <- :zip.unzip(zip, [:memory]) do
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
    end
  end

  defp download_build(frontend_info, dest) do
    Logger.info("Downloading pre-built bundle for #{frontend_info["name"]}")
    url = String.replace(frontend_info["build_url"], "${ref}", frontend_info["ref"])

    with {:ok, %{status: 200, body: zip_body}} <-
           Pleroma.HTTP.get(url, [], pool: :media, recv_timeout: 120_000) do
      unzip(zip_body, dest)
    else
      {:error, e} -> {:error, e}
      e -> {:error, e}
    end
  end

  defp install_frontend(frontend_info, source, dest) do
    from = frontend_info["build_dir"] || "dist"
    File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(Path.join([source, from]), dest)
    :ok
  end
end
