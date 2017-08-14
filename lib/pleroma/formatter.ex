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

  def finmojifiy(text) do
    emoji_list = [
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

    Enum.reduce(emoji_list, text, fn (emoji, text) ->
      String.replace(text, ":#{String.replace(emoji, "_", "")}:", "<img height='32px' width='32px' alt='#{emoji}' title='#{emoji}' src='#{Pleroma.Web.Endpoint.static_url}/finmoji/128px/#{emoji}-128.png' />")
    end)
  end
end
