# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Emoji do
  use Mix.Task

  @shortdoc "Manages Pleroma instance"
  @moduledoc """
  """

  @default_manifest "https://git.pleroma.social/vaartis/emoji-index/raw/master/index.json"

  defp fetch_manifest(from) do
    Tesla.get!(from).body |> Poison.decode!()
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

  def run(["ls-packs" | args]) do
    Application.ensure_all_started(:hackney)

    {options, [], []} = parse_global_opts(args)

    manifest =
      fetch_manifest(if options[:manifest], do: options[:manifest], else: @default_manifest)

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
    end)
  end

  def run(["get-packs" | args]) do
    Application.ensure_all_started(:hackney)

    {options, pack_names, []} = parse_global_opts(args)

    manifest =
      fetch_manifest(if options[:manifest], do: options[:manifest], else: @default_manifest)

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

        binary_archive = Tesla.get!(src_url).body

        IO.puts(IO.ANSI.format(["Unpacking ", :bright, pack_name]))

        static_path = Path.join(:code.priv_dir(:pleroma), "static")

        pack_path =
          Path.join([
            static_path,
            Pleroma.Config.get!([:instance, :static_dir]),
            "emoji",
            pack_name
          ])

        files_to_unzip =
          Enum.map(
            pack["files"],
            fn {_, f} -> to_charlist(f) end
          )

        {:ok, _} =
          :zip.unzip(binary_archive,
            cwd: pack_path,
            file_list: files_to_unzip
          )

        IO.puts(IO.ANSI.format(["Writing emoji.txt for ", :bright, pack_name]))

        emoji_txt_str =
          Enum.map(
            pack["files"],
            fn {shortcode, path} ->
              "#{shortcode}, /instance/static/emoji/#{pack_name}/#{path}"
            end
          )
          |> Enum.join("\n")

        File.write!(Path.join(pack_path, "emoji.txt"), emoji_txt_str)
      else
        IO.puts(IO.ANSI.format([:bright, :red, "No pack named \"#{pack_name}\" found"]))
      end
    end
  end
end
