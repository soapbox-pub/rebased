# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji do
  @moduledoc """
  The emojis are loaded from:

    * the built-in Finmojis (if enabled in configuration),
    * the files: `config/emoji.txt` and `config/custom_emoji.txt`
    * glob paths, nested folder is used as tag name for grouping e.g. priv/static/emoji/custom/nested_folder

  This GenServer stores in an ETS table the list of the loaded emojis, and also allows to reload the list at runtime.
  """
  use GenServer
  @ets __MODULE__.Ets
  @ets_options [:ordered_set, :protected, :named_table, {:read_concurrency, true}]

  @doc false
  def start_link do
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
    emojis =
      (load_finmoji(Keyword.get(Application.get_env(:pleroma, :instance), :finmoji_enabled)) ++
         load_from_file("config/emoji.txt") ++
         load_from_file("config/custom_emoji.txt") ++
         load_from_globs(
           Keyword.get(Application.get_env(:pleroma, :emoji, []), :shortcode_globs, [])
         ))
      |> Enum.reject(fn value -> value == nil end)

    true = :ets.insert(@ets, emojis)
    :ok
  end

  @finmoji [
    "a_trusted_friend",
    "alandislands",
    "association",
    "auroraborealis",
    "baby_in_a_box",
    "bear",
    "black_gold",
    "christmasparty",
    "crosscountryskiing",
    "cupofcoffee",
    "education",
    "fashionista_finns",
    "finnishlove",
    "flag",
    "forest",
    "four_seasons_of_bbq",
    "girlpower",
    "handshake",
    "happiness",
    "headbanger",
    "icebreaker",
    "iceman",
    "joulutorttu",
    "kaamos",
    "kalsarikannit_f",
    "kalsarikannit_m",
    "karjalanpiirakka",
    "kicksled",
    "kokko",
    "lavatanssit",
    "losthopes_f",
    "losthopes_m",
    "mattinykanen",
    "meanwhileinfinland",
    "moominmamma",
    "nordicfamily",
    "out_of_office",
    "peacemaker",
    "perkele",
    "pesapallo",
    "polarbear",
    "pusa_hispida_saimensis",
    "reindeer",
    "sami",
    "sauna_f",
    "sauna_m",
    "sauna_whisk",
    "sisu",
    "stuck",
    "suomimainittu",
    "superfood",
    "swan",
    "the_cap",
    "the_conductor",
    "the_king",
    "the_voice",
    "theoriginalsanta",
    "tomoffinland",
    "torillatavataan",
    "unbreakable",
    "waiting",
    "white_nights",
    "woollysocks"
  ]
  defp load_finmoji(true) do
    tag = Keyword.get(Application.get_env(:pleroma, :emoji), :finmoji_tag)

    Enum.map(@finmoji, fn finmoji ->
      {finmoji, "/finmoji/128px/#{finmoji}-128.png", tag}
    end)
  end

  defp load_finmoji(_), do: []

  defp load_from_file(file) do
    if File.exists?(file) do
      load_from_file_stream(File.stream!(file))
    else
      []
    end
  end

  defp load_from_file_stream(stream) do
    default_tag =
      stream.path
      |> Path.basename(".txt")
      |> get_default_tag()

    stream
    |> Stream.map(&String.trim/1)
    |> Stream.map(fn line ->
      case String.split(line, ~r/,\s*/) do
        [name, file, tags] ->
          {name, file, tags}

        [name, file] ->
          {name, file, default_tag}

        _ ->
          nil
      end
    end)
    |> Enum.to_list()
  end

  @spec get_default_tag(String.t()) :: String.t()
  defp get_default_tag(file_name) when file_name in ["emoji", "custom_emojii"] do
    Keyword.get(
      Application.get_env(:pleroma, :emoji),
      String.to_existing_atom(file_name <> "_tag")
    )
  end

  defp get_default_tag(_), do: Keyword.get(Application.get_env(:pleroma, :emoji), :custom_tag)

  defp load_from_globs(globs) do
    static_path = Path.join(:code.priv_dir(:pleroma), "static")

    paths =
      Enum.map(globs, fn glob ->
        static_part =
          Path.dirname(glob)
          |> String.replace_trailing("**", "")

        Path.join(static_path, glob)
        |> Path.wildcard()
        |> Enum.map(fn path ->
          custom_folder =
            path
            |> Path.relative_to(Path.join(static_path, static_part))
            |> Path.dirname()

          [path, custom_folder]
        end)
      end)
      |> Enum.concat()

    Enum.map(paths, fn [path, custom_folder] ->
      tag =
        case custom_folder do
          "." -> Keyword.get(Application.get_env(:pleroma, :emoji), :custom_tag)
          tag -> tag
        end

      shortcode = Path.basename(path, Path.extname(path))
      external_path = Path.join("/", Path.relative_to(path, static_path))
      {shortcode, external_path, tag}
    end)
  end
end
