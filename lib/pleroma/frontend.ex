# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Frontend do
  alias Pleroma.Config
  alias Pleroma.ConfigDB
  alias Pleroma.Frontend

  require Logger

  @unknown_name "unknown"
  @frontend_types [:admin, :primary]

  defstruct [:name, :ref, :git, :build_url, :build_dir, :file, :"custom-http-headers"]

  def install(%Frontend{} = frontend) do
    frontend
    |> maybe_put_name()
    |> hydrate()
    |> validate!()
    |> do_install()
  end

  defp maybe_put_name(%{name: nil} = fe), do: Map.put(fe, :name, @unknown_name)
  defp maybe_put_name(fe), do: fe

  # Merges a named frontend with the provided one
  defp hydrate(%Frontend{name: name} = frontend) do
    get_named_frontend(name)
    |> merge(frontend)
  end

  defp do_install(%Frontend{ref: ref, name: name} = frontend) do
    dest = Path.join([dir(), name, ref])

    label = "#{name} (#{ref})"
    tmp_dir = Path.join(dir(), "tmp")

    with {_, :ok} <- {:download_or_unzip, download_or_unzip(frontend, tmp_dir)},
         Logger.info("Installing #{label} to #{dest}"),
         :ok <- install_frontend(frontend, tmp_dir, dest) do
      File.rm_rf!(tmp_dir)
      Logger.info("Frontend #{label} installed to #{dest}")
      frontend
    else
      {:download_or_unzip, _} ->
        Logger.info("Could not download or unzip the frontend")
        {:error, "Could not download or unzip the frontend"}

      _e ->
        Logger.info("Could not install the frontend")
        {:error, "Could not install the frontend"}
    end
  end

  def enable(%Frontend{} = frontend, frontend_type) when frontend_type in @frontend_types do
    with {:config_db, true} <- {:config_db, Config.get(:configurable_from_database)} do
      frontend
      |> maybe_put_name()
      |> hydrate()
      |> validate!()
      |> do_enable(frontend_type)
    else
      {:config_db, _} ->
        map = to_map(frontend)

        raise """
        Can't enable frontend; database configuration is disabled.
        Enable the frontend by manually adding this line to your config:

          config :pleroma, :frontends, #{to_string(frontend_type)}: #{inspect(map)}

        Alternatively, enable database configuration:

          config :pleroma, configurable_from_database: true
        """
    end
  end

  def do_enable(%Frontend{name: name} = frontend, frontend_type) do
    value = Keyword.put([], frontend_type, to_map(frontend))
    params = %{group: :pleroma, key: :frontends, value: value}

    with {:ok, _} <- ConfigDB.update_or_create(params),
         :ok <- Config.TransferTask.load_and_update_env([], false) do
      Logger.info("Frontend #{name} successfully enabled")
      frontend
    end
  end

  def dir do
    Config.get!([:instance, :static_dir])
    |> Path.join("frontends")
  end

  defp download_or_unzip(%Frontend{build_url: build_url} = frontend, dest)
       when is_binary(build_url),
       do: download_build(frontend, dest)

  defp download_or_unzip(%Frontend{file: file}, dest) when is_binary(file) do
    with {:ok, zip} <- File.read(Path.expand(file)) do
      unzip(zip, dest)
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

  def parse_build_url(%Frontend{ref: ref, build_url: build_url}) do
    String.replace(build_url, "${ref}", ref)
  end

  defp download_build(%Frontend{name: name} = frontend, dest) do
    Logger.info("Downloading pre-built bundle for #{name}")
    url = parse_build_url(frontend)

    with {:ok, %{status: 200, body: zip_body}} <-
           Pleroma.HTTP.get(url, [], pool: :media, recv_timeout: 120_000) do
      unzip(zip_body, dest)
    else
      {:error, e} -> {:error, e}
      e -> {:error, e}
    end
  end

  defp install_frontend(%Frontend{} = frontend, source, dest) do
    from = frontend.build_dir || "dist"
    File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(Path.join([source, from]), dest)
    :ok
  end

  # Converts a named frontend into a %Frontend{} struct
  def get_named_frontend(name) do
    [:frontends, :available, name]
    |> Config.get(%{})
    |> from_map()
  end

  def merge(%Frontend{} = fe1, %Frontend{} = fe2) do
    Map.merge(fe1, fe2, fn _key, v1, v2 ->
      # This only overrides things that are actually set
      v1 || v2
    end)
  end

  def validate!(%Frontend{ref: ref} = fe) when is_binary(ref), do: fe
  def validate!(_), do: raise("No ref given or configured")

  def from_map(frontend) when is_map(frontend) do
    struct(Frontend, atomize_keys(frontend))
  end

  def to_map(%Frontend{} = frontend) do
    frontend
    |> Map.from_struct()
    |> stringify_keys()
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
