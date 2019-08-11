# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji do
  @moduledoc """
  The emojis are loaded from:

    * emoji packs in INSTANCE-DIR/emoji
    * the files: `config/emoji.txt` and `config/custom_emoji.txt`
    * glob paths, nested folder is used as tag name for grouping e.g. priv/static/emoji/custom/nested_folder

  This GenServer stores in an ETS table the list of the loaded emojis, and also allows to reload the list at runtime.
  """
  use GenServer

  require Logger

  @type pattern :: Regex.t() | module() | String.t()
  @type patterns :: pattern() | [pattern()]
  @type group_patterns :: keyword(patterns())

  @ets __MODULE__.Ets
  @ets_options [:ordered_set, :protected, :named_table, {:read_concurrency, true}]

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Reloads the emojis from disk."
  @spec reload() :: :ok
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc "Returns the path of the emoji `name`."
  @spec get(String.t()) :: String.t() | nil
  def get(name) do
    case :ets.lookup(@ets, name) do
      [{_, path}] -> path
      _ -> nil
    end
  end

  @doc "Returns all the emojos!!"
  @spec get_all() :: [{String.t(), String.t()}, ...]
  def get_all do
    :ets.tab2list(@ets)
  end

  @doc false
  def init(_) do
    @ets = :ets.new(@ets, @ets_options)
    GenServer.cast(self(), :reload)
    {:ok, nil}
  end

  @doc false
  def handle_cast(:reload, state) do
    load()
    {:noreply, state}
  end

  @doc false
  def handle_call(:reload, _from, state) do
    load()
    {:reply, :ok, state}
  end

  @doc false
  def terminate(_, _) do
    :ok
  end

  @doc false
  def code_change(_old_vsn, state, _extra) do
    load()
    {:ok, state}
  end

  defp load do
    emoji_dir_path =
      Path.join(
        Pleroma.Config.get!([:instance, :static_dir]),
        "emoji"
      )

    emoji_groups = Pleroma.Config.get([:emoji, :groups])

    case File.ls(emoji_dir_path) do
      {:error, :enoent} ->
        # The custom emoji directory doesn't exist,
        # don't do anything
        nil

      {:error, e} ->
        # There was some other error
        Logger.error("Could not access the custom emoji directory #{emoji_dir_path}: #{e}")

      {:ok, results} ->
        grouped =
          Enum.group_by(results, fn file -> File.dir?(Path.join(emoji_dir_path, file)) end)

        packs = grouped[true] || []
        files = grouped[false] || []

        # Print the packs we've found
        Logger.info("Found emoji packs: #{Enum.join(packs, ", ")}")

        if not Enum.empty?(files) do
          Logger.warn(
            "Found files in the emoji folder. These will be ignored, please move them to a subdirectory\nFound files: #{
              Enum.join(files, ", ")
            }"
          )
        end

        emojis =
          Enum.flat_map(
            packs,
            fn pack -> load_pack(Path.join(emoji_dir_path, pack), emoji_groups) end
          )

        true = :ets.insert(@ets, emojis)
    end

    # Compat thing for old custom emoji handling & default emoji,
    # it should run even if there are no emoji packs
    shortcode_globs = Pleroma.Config.get([:emoji, :shortcode_globs], [])

    emojis =
      (load_from_file("config/emoji.txt", emoji_groups) ++
         load_from_file("config/custom_emoji.txt", emoji_groups) ++
         load_from_globs(shortcode_globs, emoji_groups))
      |> Enum.reject(fn value -> value == nil end)

    true = :ets.insert(@ets, emojis)

    :ok
  end

  defp load_pack(pack_dir, emoji_groups) do
    pack_name = Path.basename(pack_dir)

    pack_yaml = Path.join(pack_dir, "pack.yml")

    if File.exists?(pack_yaml) do
      yaml = RelaxYaml.Decoder.read_from_file(pack_yaml)

      yaml["files"]
      |> Enum.map(fn {name, rel_file} ->
        filename = Path.join("/emoji/#{pack_name}", rel_file)
        {name, filename, pack_name}
      end)
    else
      # Load from emoji.txt / all files
      emoji_txt = Path.join(pack_dir, "emoji.txt")

      if File.exists?(emoji_txt) do
        load_from_file(emoji_txt, emoji_groups)
      else
        extensions = Pleroma.Config.get([:emoji, :pack_extensions])

        Logger.info(
          "No emoji.txt found for pack \"#{pack_name}\", assuming all #{
            Enum.join(extensions, ", ")
          } files are emoji"
        )

        make_shortcode_to_file_map(pack_dir, extensions)
        |> Enum.map(fn {shortcode, rel_file} ->
          filename = Path.join("/emoji/#{pack_name}", rel_file)

          {shortcode, filename, [to_string(match_extra(emoji_groups, filename))]}
        end)
      end
    end
  end

  def make_shortcode_to_file_map(pack_dir, exts) do
    find_all_emoji(pack_dir, exts)
    |> Enum.map(&Path.relative_to(&1, pack_dir))
    |> Enum.map(fn f -> {f |> Path.basename() |> Path.rootname(), f} end)
    |> Enum.into(%{})
  end

  def find_all_emoji(dir, exts) do
    Enum.reduce(
      File.ls!(dir),
      [],
      fn f, acc ->
        filepath = Path.join(dir, f)

        if File.dir?(filepath) do
          acc ++ find_all_emoji(filepath, exts)
        else
          acc ++ [filepath]
        end
      end
    )
    |> Enum.filter(fn f -> Path.extname(f) in exts end)
  end

  defp load_from_file(file, emoji_groups) do
    if File.exists?(file) do
      load_from_file_stream(File.stream!(file), emoji_groups)
    else
      []
    end
  end

  defp load_from_file_stream(stream, emoji_groups) do
    stream
    |> Stream.map(&String.trim/1)
    |> Stream.map(fn line ->
      case String.split(line, ~r/,\s*/) do
        [name, file] ->
          {name, file, [to_string(match_extra(emoji_groups, file))]}

        [name, file | tags] ->
          {name, file, tags}

        _ ->
          nil
      end
    end)
    |> Enum.to_list()
  end

  defp load_from_globs(globs, emoji_groups) do
    static_path = Path.join(:code.priv_dir(:pleroma), "static")

    paths =
      Enum.map(globs, fn glob ->
        Path.join(static_path, glob)
        |> Path.wildcard()
      end)
      |> Enum.concat()

    Enum.map(paths, fn path ->
      tag = match_extra(emoji_groups, Path.join("/", Path.relative_to(path, static_path)))
      shortcode = Path.basename(path, Path.extname(path))
      external_path = Path.join("/", Path.relative_to(path, static_path))
      {shortcode, external_path, [to_string(tag)]}
    end)
  end

  @doc """
  Finds a matching group for the given emoji filename
  """
  @spec match_extra(group_patterns(), String.t()) :: atom() | nil
  def match_extra(group_patterns, filename) do
    match_group_patterns(group_patterns, fn pattern ->
      case pattern do
        %Regex{} = regex -> Regex.match?(regex, filename)
        string when is_binary(string) -> filename == string
      end
    end)
  end

  defp match_group_patterns(group_patterns, matcher) do
    Enum.find_value(group_patterns, fn {group, patterns} ->
      patterns =
        patterns
        |> List.wrap()
        |> Enum.map(fn pattern ->
          if String.contains?(pattern, "*") do
            ~r(#{String.replace(pattern, "*", ".*")})
          else
            pattern
          end
        end)

      Enum.any?(patterns, matcher) && group
    end)
  end
end
