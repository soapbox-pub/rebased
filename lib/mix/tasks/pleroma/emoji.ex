# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Emoji do
  use Mix.Task
  import Mix.Pleroma

  @shortdoc "Manages emoji packs"
  @moduledoc File.read!("docs/administration/CLI_tasks/emoji.md")

  def run(["ls-packs" | args]) do
    start_pleroma()

    {options, [], []} = parse_global_opts(args)

    url_or_path = options[:manifest] || default_manifest()
    manifest = fetch_and_decode!(url_or_path)

    Enum.each(manifest, fn {name, info} ->
      to_print = [
        {"Name", name},
        {"Homepage", info["homepage"]},
        {"Description", info["description"]},
        {"License", info["license"]},
        {"Source", info["src"]}
      ]

      for {param, value} <- to_print do
        IO.puts(IO.ANSI.format([:bright, param, :normal, ": ", value]))
      end

      # A newline
      IO.puts("")
    end)
  end

  def run(["get-packs" | args]) do
    start_pleroma()

    {options, pack_names, []} = parse_global_opts(args)

    url_or_path = options[:manifest] || default_manifest()

    manifest = fetch_and_decode!(url_or_path)

    for pack_name <- pack_names do
      if Map.has_key?(manifest, pack_name) do
        pack = manifest[pack_name]
        src = pack["src"]

        IO.puts(
          IO.ANSI.format([
            "Downloading ",
            :bright,
            pack_name,
            :normal,
            " from ",
            :underline,
            src
          ])
        )

        {:ok, binary_archive} = fetch(src)
        archive_sha = :crypto.hash(:sha256, binary_archive) |> Base.encode16()

        sha_status_text = ["SHA256 of ", :bright, pack_name, :normal, " source file is ", :bright]

        if archive_sha == String.upcase(pack["src_sha256"]) do
          IO.puts(IO.ANSI.format(sha_status_text ++ [:green, "OK"]))
        else
          IO.puts(IO.ANSI.format(sha_status_text ++ [:red, "BAD"]))

          raise "Bad SHA256 for #{pack_name}"
        end

        # The location specified in files should be in the same directory
        files_loc =
          url_or_path
          |> Path.dirname()
          |> Path.join(pack["files"])

        IO.puts(
          IO.ANSI.format([
            "Fetching the file list for ",
            :bright,
            pack_name,
            :normal,
            " from ",
            :underline,
            files_loc
          ])
        )

        files = fetch_and_decode!(files_loc)

        IO.puts(IO.ANSI.format(["Unpacking ", :bright, pack_name]))

        pack_path =
          Path.join([
            Pleroma.Config.get!([:instance, :static_dir]),
            "emoji",
            pack_name
          ])

        files_to_unzip =
          Enum.map(
            files,
            fn {_, f} -> to_charlist(f) end
          )

        {:ok, _} =
          :zip.unzip(binary_archive,
            cwd: pack_path,
            file_list: files_to_unzip
          )

        IO.puts(IO.ANSI.format(["Writing pack.json for ", :bright, pack_name]))

        pack_json = %{
          pack: %{
            "license" => pack["license"],
            "homepage" => pack["homepage"],
            "description" => pack["description"],
            "fallback-src" => pack["src"],
            "fallback-src-sha256" => pack["src_sha256"],
            "share-files" => true
          },
          files: files
        }

        File.write!(Path.join(pack_path, "pack.json"), Jason.encode!(pack_json, pretty: true))
      else
        IO.puts(IO.ANSI.format([:bright, :red, "No pack named \"#{pack_name}\" found"]))
      end
    end
  end

  def run(["gen-pack" | args]) do
    start_pleroma()

    {opts, [src], []} =
      OptionParser.parse(
        args,
        strict: [
          name: :string,
          license: :string,
          homepage: :string,
          description: :string,
          files: :string,
          extensions: :string
        ]
      )

    proposed_name = Path.basename(src) |> Path.rootname()
    name = get_option(opts, :name, "Pack name:", proposed_name)
    license = get_option(opts, :license, "License:")
    homepage = get_option(opts, :homepage, "Homepage:")
    description = get_option(opts, :description, "Description:")

    proposed_files_name = "#{name}_files.json"
    files_name = get_option(opts, :files, "Save file list to:", proposed_files_name)

    default_exts = [".png", ".gif"]

    custom_exts =
      get_option(
        opts,
        :extensions,
        "Emoji file extensions (separated with spaces):",
        Enum.join(default_exts, " ")
      )
      |> String.split(" ", trim: true)

    exts =
      if MapSet.equal?(MapSet.new(default_exts), MapSet.new(custom_exts)) do
        default_exts
      else
        custom_exts
      end

    IO.puts("Using #{Enum.join(exts, " ")} extensions")

    IO.puts("Downloading the pack and generating SHA256")

    {:ok, %{body: binary_archive}} = Pleroma.HTTP.get(src)
    archive_sha = :crypto.hash(:sha256, binary_archive) |> Base.encode16()

    IO.puts("SHA256 is #{archive_sha}")

    pack_json = %{
      name => %{
        license: license,
        homepage: homepage,
        description: description,
        src: src,
        src_sha256: archive_sha,
        files: files_name
      }
    }

    tmp_pack_dir = Path.join(System.tmp_dir!(), "emoji-pack-#{name}")

    {:ok, _} = :zip.unzip(binary_archive, cwd: String.to_charlist(tmp_pack_dir))

    emoji_map = Pleroma.Emoji.Loader.make_shortcode_to_file_map(tmp_pack_dir, exts)

    File.write!(files_name, Jason.encode!(emoji_map, pretty: true))

    IO.puts("""

    #{files_name} has been created and contains the list of all found emojis in the pack.
    Please review the files in the pack and remove those not needed.
    """)

    pack_file = "#{name}.json"

    if File.exists?(pack_file) do
      existing_data = File.read!(pack_file) |> Jason.decode!()

      File.write!(
        pack_file,
        Jason.encode!(
          Map.merge(
            existing_data,
            pack_json
          ),
          pretty: true
        )
      )

      IO.puts("#{pack_file} has been updated with the #{name} pack")
    else
      File.write!(pack_file, Jason.encode!(pack_json, pretty: true))

      IO.puts("#{pack_file} has been created with the #{name} pack")
    end
  end

  def run(["reload"]) do
    start_pleroma()
    Pleroma.Emoji.reload()
    IO.puts("Emoji packs have been reloaded.")
  end

  defp fetch_and_decode!(from) do
    with {:ok, json} <- fetch(from) do
      Jason.decode!(json)
    else
      {:error, error} -> raise "#{from} cannot be fetched. Error: #{error} occur."
    end
  end

  defp fetch("http" <> _ = from) do
    with {:ok, %{body: body}} <- Pleroma.HTTP.get(from) do
      {:ok, body}
    end
  end

  defp fetch(path), do: File.read(path)

  defp parse_global_opts(args) do
    OptionParser.parse(
      args,
      strict: [
        manifest: :string
      ],
      aliases: [
        m: :manifest
      ]
    )
  end

  defp default_manifest, do: Pleroma.Config.get!([:emoji, :default_manifest])
end
