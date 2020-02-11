# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCardTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.RichMedia.Parsers.TwitterCard

  test "returns error when html not contains twitter card" do
    assert TwitterCard.parse([{"html", [], [{"head", [], []}, {"body", [], []}]}], %{}) ==
             {:error, "No twitter card metadata found"}
  end

  test "parses twitter card with only name attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers3.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             {:ok,
              %{
                "app:id:googleplay": "com.nytimes.android",
                "app:name:googleplay": "NYTimes",
                "app:url:googleplay": "nytimes://reader/id/100000006583622",
                site: nil,
                title:
                  "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database. - The New York Times"
              }}
  end

  test "parses twitter card with only property attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers2.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             {:ok,
              %{
                card: "summary_large_image",
                description:
                  "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
                image:
                  "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-videoSixteenByNineJumbo1600.jpg",
                "image:alt": "",
                title:
                  "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
                url:
                  "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html"
              }}
  end

  test "parses twitter card with name & property attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             {:ok,
              %{
                "app:id:googleplay": "com.nytimes.android",
                "app:name:googleplay": "NYTimes",
                "app:url:googleplay": "nytimes://reader/id/100000006583622",
                card: "summary_large_image",
                description:
                  "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
                image:
                  "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-videoSixteenByNineJumbo1600.jpg",
                "image:alt": "",
                site: nil,
                title:
                  "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
                url:
                  "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html"
              }}
  end

  test "respect only first title tag on the page" do
    image_path =
      "https://assets.atlasobscura.com/media/W1siZiIsInVwbG9hZHMvYXNzZXRzLzkwYzgyMzI4LThlMDUtNGRiNS05MDg3LTUzMGUxZTM5N2RmMmVkOTM5ZDM4MGM4OTIx" <>
        "YTQ5MF9EQVIgZXhodW1hdGlvbiBvZiBNYXJnYXJldCBDb3JiaW4gZ3JhdmUgMTkyNi5qcGciXSxbInAiLCJjb252ZXJ0IiwiIl0sWyJwIiwiY29udmVydCIsIi1xdWFsaXR5IDgxIC1hdXRvLW9" <>
        "yaWVudCJdLFsicCIsInRodW1iIiwiNjAweD4iXV0/DAR%20exhumation%20of%20Margaret%20Corbin%20grave%201926.jpg"

    html =
      File.read!("test/fixtures/margaret-corbin-grave-west-point.html") |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             {:ok,
              %{
                site: "@atlasobscura",
                title:
                  "The Missing Grave of Margaret Corbin, Revolutionary War Veteran - Atlas Obscura",
                card: "summary_large_image",
                image: image_path
              }}
  end

  test "takes first founded title in html head if there is html markup error" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers4.html")
      |> Floki.parse_document!()

    assert TwitterCard.parse(html, %{}) ==
             {:ok,
              %{
                site: nil,
                title:
                  "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database. - The New York Times",
                "app:id:googleplay": "com.nytimes.android",
                "app:name:googleplay": "NYTimes",
                "app:url:googleplay": "nytimes://reader/id/100000006583622"
              }}
  end
end
