# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCardTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.RichMedia.Parsers.TwitterCard

  test "fails gracefully with barebones HTML" do
    html = [{"html", [], [{"head", [], []}, {"body", [], []}]}]
    expected = %{meta: %{}, title: nil}
    assert TwitterCard.parse(html, %{}) == expected
  end

  test "parses twitter card with only name attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers3.html")
      |> Floki.parse_document!()

    assert %{
             title:
               "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database. - The New York Times",
             meta: %{
               "twitter:app:id:googleplay" => "com.nytimes.android",
               "twitter:app:name:googleplay" => "NYTimes",
               "twitter:app:url:googleplay" => "nytimes://reader/id/100000006583622",
               "og:description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "og:image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "og:title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "og:type" => "article",
               "og:url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html"
             }
           } = TwitterCard.parse(html, %{})
  end

  test "parses twitter card with only property attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers2.html")
      |> Floki.parse_document!()

    assert %{
             title:
               "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database. - The New York Times",
             meta: %{
               "twitter:card" => "summary_large_image",
               "twitter:description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "twitter:image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-videoSixteenByNineJumbo1600.jpg",
               "twitter:image:alt" => "",
               "twitter:title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "twitter:url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "og:description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "og:image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "og:title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "og:url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "og:type" => "article"
             }
           } = TwitterCard.parse(html, %{})
  end

  test "parses twitter card with name & property attributes" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers.html")
      |> Floki.parse_document!()

    assert %{
             title:
               "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database. - The New York Times",
             meta: %{
               "twitter:app:id:googleplay" => "com.nytimes.android",
               "twitter:app:name:googleplay" => "NYTimes",
               "twitter:app:url:googleplay" => "nytimes://reader/id/100000006583622",
               "twitter:card" => "summary_large_image",
               "twitter:description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "twitter:image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-videoSixteenByNineJumbo1600.jpg",
               "twitter:image:alt" => "",
               "twitter:title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "twitter:url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "og:description" =>
                 "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
               "og:image" =>
                 "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
               "og:title" =>
                 "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
               "og:url" =>
                 "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
               "og:type" => "article"
             }
           } = TwitterCard.parse(html, %{})
  end

  test "respect only first title tag on the page" do
    html =
      File.read!("test/fixtures/margaret-corbin-grave-west-point.html") |> Floki.parse_document!()

    expected = "The Missing Grave of Margaret Corbin, Revolutionary War Veteran - Atlas Obscura"

    assert %{title: ^expected} = TwitterCard.parse(html, %{})
  end

  test "takes first title found in html head if there is an html markup error" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers4.html")
      |> Floki.parse_document!()

    expected =
      "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database. - The New York Times"

    assert %{title: ^expected} = TwitterCard.parse(html, %{})
  end
end
