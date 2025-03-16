# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCardTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.RichMedia.Parsers.TwitterCard

  test "returns error when html not contains twitter card" do
    assert TwitterCard.parse([{"html", [], [{"head", [], []}, {"body", [], []}]}], %{}) == %{}
  end

  test "parses twitter card with only name attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers3.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             %{
               "description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "type" => "article",
               "url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database."
             }
  end

  test "parses twitter card with only property attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers2.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             %{
               "card" => "summary_large_image",
               "description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "image:alt" => "",
               "title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "type" => "article"
             }
  end

  test "parses twitter card with name & property attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             %{
               "card" => "summary_large_image",
               "description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "image:alt" => "",
               "title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "type" => "article"
             }
  end

  test "respect only first title tag on the page" do
    image_path =
      "https://assets.atlasobscura.com/media/W1siZiIsInVwbG9hZHMvYXNzZXRzLzkwYzgyMzI4LThlMDUtNGRiNS05MDg3LTUzMGUxZTM5N2RmMmVkOTM5ZDM4MGM4OTIx" <>
        "YTQ5MF9EQVIgZXhodW1hdGlvbiBvZiBNYXJnYXJldCBDb3JiaW4gZ3JhdmUgMTkyNi5qcGciXSxbInAiLCJjb252ZXJ0IiwiIl0sWyJwIiwiY29udmVydCIsIi1xdWFsaXR5IDgxIC1hdXRvLW9" <>
        "yaWVudCJdLFsicCIsInRodW1iIiwiNjAweD4iXV0/DAR%20exhumation%20of%20Margaret%20Corbin%20grave%201926.jpg"

    html =
      File.read!("test/fixtures/margaret-corbin-grave-west-point.html") |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             %{
               "title" => "The Missing Grave of Margaret Corbin, Revolutionary War Veteran",
               "card" => "summary_large_image",
               "image" => image_path,
               "description" =>
                 "She's the only woman veteran honored with a monument at West Point. But where was she buried?",
               "type" => "article",
               "url" => "http://www.atlasobscura.com/articles/margaret-corbin-grave-west-point"
             }
  end

  test "takes first title found in html head if there is an html markup error" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers4.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             %{
               "title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "type" => "article",
               "url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html"
             }
  end

  test "takes first image if multiple are specified" do
    html =
      File.read!("test/fixtures/fulmo.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             %{
               "description" => "Pri feoj, kiuj devis ordigi falintan arbon.",
               "image" => "https://tirifto.xwx.moe/r/ilustrajhoj/pinglordigado.png",
               "title" => "Fulmo",
               "type" => "website",
               "url" => "https://tirifto.xwx.moe/eo/rakontoj/fulmo.html",
               "image:alt" =>
                 "Meze de arbaro kuŝas falinta trunko, sen pingloj kaj kun branĉoj derompitaj. Post ĝi videblas du feoj: florofeo maldekstre kaj nubofeo dekstre. La florofeo iom kaŝas sin post la trunko. La nubofeo staras kaj tenas amason da pigloj. Ili iom rigardas al si.",
               "image:height" => "630",
               "image:width" => "1200"
             }
  end
end
