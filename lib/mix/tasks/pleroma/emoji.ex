# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Emoji do
  use Mix.Task
  import Mix.Pleroma

  @shortdoc "Manages emoji packs"
  @moduledoc File.read!("docs/administration/CLI_tasks/emoji.md")

  def run(["ls-packs" | args]) do
    start_pleroma()

    {options, [], []} = parse_global_opts(args)

    manifest =
      fetch_manifest(if options[:manifest], do: options[:manifest], else: default_manifest())

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

    manifest_url = if options[:manifest], do: options[:manifest], else: default_manifest()

    manifest = fetch_manifest(manifest_url)

    for pack_name <- pack_names do
      if Map.has_key?(manifest, pack_name) do
        pack = manifest[pack_name]
        src_url = pack["src"]

        IO.puts(
          IO.ANSI.format([
            "Downloading ",
            :bright,
            pack_name,
            :normal,
            " from ",
            :underline,
            src_url
          ])
        )

        binary_archive = Tesla.get!(client(), src_url).body
        archive_sha = :crypto.hash(:sha256, binary_archive) |> Base.encode16()

        sha_status_text = ["SHA256 of ", :bright, pack_name, :normal, " source file is ", :bright]

        if archive_sha == String.upcase(pack["src_sha256"]) do
          IO.puts(IO.ANSI.format(sha_status_text ++ [:green, "OK"]))
        else
          IO.puts(IO.ANSI.format(sha_status_text ++ [:red, "BAD"]))

          raise "Bad SHA256 for #{pack_name}"
        end

        # The url specified in files should be in the same directory
        files_url = Path.join(Path.dirname(manifest_url), pack["files"])

        IO.puts(
          IO.ANSI.format([
            "Fetching the file list for ",
            :bright,
            pack_name,
            :normal,
            " from ",
            :underline,
            files_url
          ])
        )

        files = Tesla.get!(client(), files_url).body |> Jason.decode!()

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

  def run(["gen-pack", src]) do
    start_pleroma()

    proposed_name = Path.basename(src) |> Path.rootname()
    name = String.trim(IO.gets("Pack name [#{proposed_name}]: "))
    # If there's no name, use the default one
    name = if String.length(name) > 0, do: name, else: proposed_name

    license = String.trim(IO.gets("License: "))
    homepage = String.trim(IO.gets("Homepage: "))
    description = String.trim(IO.gets("Description: "))

    proposed_files_name = "#{name}.json"
    files_name = String.trim(IO.gets("Save file list to [#{proposed_files_name}]: "))
    files_name = if String.length(files_name) > 0, do: files_name, else: proposed_files_name

    default_exts = [".png", ".gif"]
    default_exts_str = Enum.join(default_exts, " ")

    exts =
      String.trim(
        IO.gets("Emoji file extensions (separated with spaces) [#{default_exts_str}]: ")
      )

    exts =
      if String.length(exts) > 0 do
        String.split(exts, " ")
        |> Enum.filter(fn e -> e |> String.trim() |> String.length() > 0 end)
      else
        default_exts
      end

    IO.puts("Downloading the pack and generating SHA256")

    binary_archive = Tesla.get!(client(), src).body
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
    Please review the files in the remove those not needed.
    """)

    if File.exists?("index.json") do
      existing_data = File.read!("index.json") |> Jason.decode!()

      File.write!(
        "index.json",
        Jason.encode!(
          Map.merge(
            existing_data,
            pack_json
          ),
          pretty: true
        )
      )

      IO.puts("index.json file has been update with the #{name} pack")
    else
      File.write!("index.json", Jason.encode!(pack_json, pretty: true))

      IO.puts("index.json has been created with the #{name} pack")
    end
  end

  defp fetch_manifest(from) do
    Jason.decode!(
      if String.starts_with?(from, "http") do
        Tesla.get!(client(), from).body
      else
        File.read!(from)
      end
    )
  end

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

  defp client do
    middleware = [
      {Tesla.Middleware.FollowRedirects, [max_redirects: 3]}
    ]

    Tesla.client(middleware)
  end

  defp default_manifest, do: Pleroma.Config.get!([:emoji, :default_manifest])
end
