# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.CardTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.RichMedia.Parser.Card
  alias Pleroma.Web.RichMedia.Parser.Embed
  alias Pleroma.Web.RichMedia.Parsers.TwitterCard

  describe "parse/1" do
    test "converts an %Embed{} into a %Card{}" do
      url =
        "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html"

      embed =
        File.read!("test/fixtures/nypd-facial-recognition-children-teenagers.html")
        |> Floki.parse_document!()
        |> TwitterCard.parse(%Embed{url: url})

      expected = %Card{
        description:
          "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
        image:
          "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-videoSixteenByNineJumbo1600.jpg",
        title: "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
        type: "link",
        provider_name: "www.nytimes.com",
        provider_url: "https://www.nytimes.com",
        url: url
      }

      assert Card.parse(embed) == {:ok, expected}
    end

    test "converts URL paths into absolute URLs" do
      embed = %Embed{
        url: "https://spam.com/luigi",
        title: "Watch Luigi not doing anything",
        meta: %{
          "og:image" => "/uploads/weegee.jpeg"
        }
      }

      {:ok, card} = Card.parse(embed)
      assert card.image == "https://spam.com/uploads/weegee.jpeg"
    end

    test "falls back to Link with invalid Rich/Video" do
      url = "https://ishothim.com/our-work/mexican-drug-cartels/"
      oembed = File.read!("test/fixtures/rich_media/wordpress_embed.json") |> Jason.decode!()

      embed =
        File.read!("test/fixtures/rich_media/wordpress.html")
        |> Floki.parse_document!()
        |> TwitterCard.parse(%Embed{url: url, oembed: oembed})

      expected = %Card{
        author_name: "Michael Jeter",
        author_url: "https://ishothim.com/author/mike/",
        blurhash: nil,
        description:
          "I Shot Him collaborated with the folks at Visual.ly on this informative animation about the violence from drug cartels happening right across our border. We researched, wrote, illustrated, and animated this piece to inform people about the connections of our drug and gun laws to the death of innocence in Mexico.",
        embed_url: nil,
        height: 338,
        html: "",
        image: "https://ishothim.com/wp-content/uploads/2013/01/Cartel_feature.jpg",
        provider_name: "I Shot Him",
        provider_url: "https://ishothim.com",
        title: "Mexican Drug Cartels",
        type: "link",
        url: "https://ishothim.com/our-work/mexican-drug-cartels/",
        width: 600
      }

      assert Card.parse(embed) == {:ok, expected}
    end
  end

  describe "validate/1" do
    test "returns {:ok, card} with a valid %Card{}" do
      card = %Card{
        title: "Moms can't believe this one trick",
        url: "http://spam.com",
        type: "link"
      }

      assert {:ok, ^card} = Card.validate(card)
    end
  end

  describe "fix_uri/2" do
    setup do: %{base_uri: "https://benis.xyz/hello/fam"}

    test "two full URLs", %{base_uri: base_uri} do
      uri = "https://benis.xyz/images/pic.jpeg"
      assert Card.fix_uri(uri, base_uri) == uri
    end

    test "URI with leading slash", %{base_uri: base_uri} do
      uri = "/images/pic.jpeg"
      expected = "https://benis.xyz/images/pic.jpeg"
      assert Card.fix_uri(uri, base_uri) == expected
    end

    test "URI without leading slash", %{base_uri: base_uri} do
      uri = "images/pic.jpeg"
      expected = "https://benis.xyz/images/pic.jpeg"
      assert Card.fix_uri(uri, base_uri) == expected
    end

    test "empty URI", %{base_uri: base_uri} do
      assert Card.fix_uri("", base_uri) == nil
    end

    test "nil URI", %{base_uri: base_uri} do
      assert Card.fix_uri(nil, base_uri) == nil
    end

    # https://github.com/elixir-lang/elixir/issues/10771
    test "Elixir #10771", _ do
      uri =
        "https://images.macrumors.com/t/4riJyi1XC906qyJ41nAfOgpvo1I=/1600x/https://images.macrumors.com/article-new/2020/09/spatialaudiofeature.jpg"

      base_uri = "https://www.macrumors.com/guide/apps-support-apples-spatial-audio-feature/"
      assert Card.fix_uri(uri, base_uri) == uri
    end
  end
end
