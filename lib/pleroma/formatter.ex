defmodule Pleroma.Formatter do
  alias Pleroma.User

  @link_regex ~r/https?:\/\/[\w\.\/?=\-#%&]+[\w]/u
  def linkify(text) do
    Regex.replace(@link_regex, text, "<a href='\\0'>\\0</a>")
  end

  @tag_regex ~r/\#\w+/u
  def parse_tags(text) do
    Regex.scan(@tag_regex, text)
    |> Enum.map(fn (["#" <> tag = full_tag]) -> {full_tag, String.downcase(tag)} end)
  end

  def parse_mentions(text) do
    # Modified from https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
    regex = ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/u

    Regex.scan(regex, text)
    |> List.flatten
    |> Enum.uniq
    |> Enum.map(fn ("@" <> match = full_match) -> {full_match, User.get_cached_by_nickname(match)} end)
    |> Enum.filter(fn ({_match, user}) -> user end)
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

  @finmoji_with_filenames Enum.map(@finmoji, fn (finmoji) ->
    {finmoji, "/finmoji/128px/#{finmoji}-128.png"}
  end)

  @emoji_from_file (with {:ok, file} <- File.read("config/emoji.txt") do
                     file
                     |> String.trim
                     |> String.split("\n")
                     |> Enum.map(fn(line) ->
                       [name, file] = String.split(line, ", ")
                       {name, file}
                     end)
                    else
                      _ -> []
                   end)

  @emoji @finmoji_with_filenames ++ @emoji_from_file

  def emojify(text, additional \\ nil) do
    all_emoji = if additional do
      Map.to_list(additional) ++ @emoji
    else
      @emoji
    end

    Enum.reduce(all_emoji, text, fn ({emoji, file}, text) ->
      String.replace(text, ":#{emoji}:", "<img height='32px' width='32px' alt='#{emoji}' title='#{emoji}' src='#{file}' />")
    end)
  end

  def get_emoji(text) do
    Enum.filter(@emoji, fn ({emoji, _}) -> String.contains?(text, ":#{emoji}:") end)
  end

  def get_custom_emoji() do
    @emoji
    |> Enum.into %{}
  end
end
