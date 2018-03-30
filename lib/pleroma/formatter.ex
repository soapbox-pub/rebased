defmodule Pleroma.Formatter do
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy

  @tag_regex ~r/\#\w+/u
  def parse_tags(text, data \\ %{}) do
    Regex.scan(@tag_regex, text)
    |> Enum.map(fn ["#" <> tag = full_tag] -> {full_tag, String.downcase(tag)} end)
    |> (fn map ->
          if data["sensitive"] in [true, "True", "true", "1"],
            do: [{"#nsfw", "nsfw"}] ++ map,
            else: map
        end).()
  end

  def parse_mentions(text) do
    # Modified from https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
    regex =
      ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/u

    Regex.scan(regex, text)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(fn "@" <> match = full_match ->
      {full_match, User.get_cached_by_nickname(match)}
    end)
    |> Enum.filter(fn {_match, user} -> user end)
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

  @finmoji_with_filenames Enum.map(@finmoji, fn finmoji ->
                            {finmoji, "/finmoji/128px/#{finmoji}-128.png"}
                          end)

  @emoji_from_file (with {:ok, default} <- File.read("config/emoji.txt") do
                      custom =
                        with {:ok, custom} <- File.read("config/custom_emoji.txt") do
                          custom
                        else
                          _e -> ""
                        end

                      (default <> "\n" <> custom)
                      |> String.trim()
                      |> String.split(~r/\n+/)
                      |> Enum.map(fn line ->
                        [name, file] = String.split(line, ~r/,\s*/)
                        {name, file}
                      end)
                    else
                      _ -> []
                    end)

  @emoji @finmoji_with_filenames ++ @emoji_from_file

  def emojify(text, emoji \\ @emoji)
  def emojify(text, nil), do: text

  def emojify(text, emoji) do
    Enum.reduce(emoji, text, fn {emoji, file}, text ->
      emoji = HtmlSanitizeEx.strip_tags(emoji)
      file = HtmlSanitizeEx.strip_tags(file)

      String.replace(
        text,
        ":#{emoji}:",
        "<img height='32px' width='32px' alt='#{emoji}' title='#{emoji}' src='#{
          MediaProxy.url(file)
        }' />"
      )
    end)
  end

  def get_emoji(text) do
    Enum.filter(@emoji, fn {emoji, _} -> String.contains?(text, ":#{emoji}:") end)
  end

  def get_custom_emoji() do
    @emoji
  end

  @link_regex ~r/https?:\/\/[\w\.\/?=\-#%&@~\(\)]+[\w\/]/u

  def html_escape(text) do
    Regex.split(@link_regex, text, include_captures: true)
    |> Enum.map_every(2, fn chunk ->
      {:safe, part} = Phoenix.HTML.html_escape(chunk)
      part
    end)
    |> Enum.join("")
  end

  @doc "changes http:... links to html links"
  def add_links({subs, text}) do
    links =
      Regex.scan(@link_regex, text)
      |> Enum.map(fn [url] -> {Ecto.UUID.generate(), url} end)

    uuid_text =
      links
      |> Enum.reduce(text, fn {uuid, url}, acc -> String.replace(acc, url, uuid) end)

    subs =
      subs ++
        Enum.map(links, fn {uuid, url} ->
          {uuid, "<a href='#{url}'>#{url}</a>"}
        end)

    {subs, uuid_text}
  end

  @doc "Adds the links to mentioned users"
  def add_user_links({subs, text}, mentions) do
    mentions =
      mentions
      |> Enum.sort_by(fn {name, _} -> -String.length(name) end)
      |> Enum.map(fn {name, user} -> {name, user, Ecto.UUID.generate()} end)

    uuid_text =
      mentions
      |> Enum.reduce(text, fn {match, _user, uuid}, text ->
        String.replace(text, match, uuid)
      end)

    subs =
      subs ++
        Enum.map(mentions, fn {match, %User{ap_id: ap_id}, uuid} ->
          short_match = String.split(match, "@") |> tl() |> hd()
          {uuid, "<span><a href='#{ap_id}'>@<span>#{short_match}</span></a></span>"}
        end)

    {subs, uuid_text}
  end

  @doc "Adds the hashtag links"
  def add_hashtag_links({subs, text}, tags) do
    tags =
      tags
      |> Enum.sort_by(fn {name, _} -> -String.length(name) end)
      |> Enum.map(fn {name, short} -> {name, short, Ecto.UUID.generate()} end)

    uuid_text =
      tags
      |> Enum.reduce(text, fn {match, _short, uuid}, text ->
        String.replace(text, match, uuid)
      end)

    subs =
      subs ++
        Enum.map(tags, fn {_, tag, uuid} ->
          url = "<a href='#{Pleroma.Web.base_url()}/tag/#{tag}' rel='tag'>##{tag}</a>"
          {uuid, url}
        end)

    {subs, uuid_text}
  end

  def finalize({subs, text}) do
    Enum.reduce(subs, text, fn {uuid, replacement}, result_text ->
      String.replace(result_text, uuid, replacement)
    end)
  end
end
