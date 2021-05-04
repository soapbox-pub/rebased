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
end
