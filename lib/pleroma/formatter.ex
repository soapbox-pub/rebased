defmodule Pleroma.Formatter do
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy
  alias Pleroma.HTML

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
      ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]*@?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/u

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

  @emoji_from_globs (
                      static_path = Path.join(:code.priv_dir(:pleroma), "static")

                      globs =
                        Application.get_env(:pleroma, :emoji, [])
                        |> Keyword.get(:shortcode_globs, [])

                      paths =
                        Enum.map(globs, fn glob ->
                          Path.join(static_path, glob)
                          |> Path.wildcard()
                        end)
                        |> Enum.concat()

                      Enum.map(paths, fn path ->
                        shortcode = Path.basename(path, Path.extname(path))
                        external_path = Path.join("/", Path.relative_to(path, static_path))
                        {shortcode, external_path}
                      end)
                    )

  @emoji @finmoji_with_filenames ++ @emoji_from_globs ++ @emoji_from_file

  def emojify(text, emoji \\ @emoji)
  def emojify(text, nil), do: text

  def emojify(text, emoji) do
    Enum.reduce(emoji, text, fn {emoji, file}, text ->
      emoji = HTML.strip_tags(emoji)
      file = HTML.strip_tags(file)

      String.replace(
        text,
        ":#{emoji}:",
        "<img height='32px' width='32px' alt='#{emoji}' title='#{emoji}' src='#{
          MediaProxy.url(file)
        }' />"
      )
      |> HTML.filter_tags()
    end)
  end

  def get_emoji(text) when is_binary(text) do
    Enum.filter(@emoji, fn {emoji, _} -> String.contains?(text, ":#{emoji}:") end)
  end

  def get_emoji(_), do: []

  def get_custom_emoji() do
    @emoji
  end

  @link_regex ~r/[0-9a-z+\-\.]+:[0-9a-z$-_.+!*'(),]+/ui

  # IANA got a list https://www.iana.org/assignments/uri-schemes/ but
  # Stuff like ipfs isn’t in it
  # There is very niche stuff
  @uri_schemes [
    "https://",
    "http://",
    "dat://",
    "dweb://",
    "gopher://",
    "ipfs://",
    "ipns://",
    "irc:",
    "ircs:",
    "magnet:",
    "mailto:",
    "mumble:",
    "ssb://",
    "xmpp:"
  ]

  # TODO: make it use something other than @link_regex
  def html_escape(text, "text/html") do
    HtmlSanitizeEx.basic_html(text)
  end

  def html_escape(text, "text/plain") do
    Regex.split(@link_regex, text, include_captures: true)
    |> Enum.map_every(2, fn chunk ->
      {:safe, part} = Phoenix.HTML.html_escape(chunk)
      part
    end)
    |> Enum.join("")
  end

  @doc "changes scheme:... urls to html links"
  def add_links({subs, text}) do
    additionnal_schemes =
      Application.get_env(:pleroma, :uri_schemes, [])
      |> Keyword.get(:additionnal_schemes, [])

    links =
      text
      |> String.split([" ", "\t", "<br>"])
      |> Enum.filter(fn word -> String.starts_with?(word, @uri_schemes ++ additionnal_schemes) end)
      |> Enum.filter(fn word -> Regex.match?(@link_regex, word) end)
      |> Enum.map(fn url -> {Ecto.UUID.generate(), url} end)
      |> Enum.sort_by(fn {_, url} -> -String.length(url) end)

    uuid_text =
      links
      |> Enum.reduce(text, fn {uuid, url}, acc -> String.replace(acc, url, uuid) end)

    subs =
      subs ++
        Enum.map(links, fn {uuid, url} ->
          {uuid, "<a href=\"#{url}\">#{url}</a>"}
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
        Enum.map(mentions, fn {match, %User{ap_id: ap_id, info: info}, uuid} ->
          ap_id = info["source_data"]["url"] || ap_id

          short_match = String.split(match, "@") |> tl() |> hd()

          {uuid,
           "<span><a class='mention' href='#{ap_id}'>@<span>#{short_match}</span></a></span>"}
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
        Enum.map(tags, fn {tag_text, tag, uuid} ->
          url = "<a href='#{Pleroma.Web.base_url()}/tag/#{tag}' rel='tag'>#{tag_text}</a>"
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
