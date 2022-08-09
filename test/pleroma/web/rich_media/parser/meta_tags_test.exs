# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.MetaTagsTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.RichMedia.Parser.MetaTags

  test "returns a map of <meta> values" do
    html =
      File.read!("test/fixtures/nypd-facial-recognition-children-teenagers.html")
      |> Floki.parse_document!()

    expected = %{
      "CG" => "nyregion",
      "CN" => "experience-tech-and-society",
      "CT" => "spotlight",
      "PST" => "News",
      "PT" => "article",
      "SCG" => "",
      "al:android:app_name" => "NYTimes",
      "al:android:package" => "com.nytimes.android",
      "al:android:url" => "nytimes://reader/id/100000006583622",
      "al:ipad:app_name" => "NYTimes",
      "al:ipad:app_store_id" => "357066198",
      "al:ipad:url" =>
        "nytimes://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
      "al:iphone:app_name" => "NYTimes",
      "al:iphone:app_store_id" => "284862083",
      "al:iphone:url" =>
        "nytimes://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
      "article:modified" => "2019-08-02T09:30:23.000Z",
      "article:published" => "2019-08-01T17:15:31.000Z",
      "article:section" => "New York",
      "article:tag" => "New York City",
      "articleid" => "100000006583622",
      "byl" => "By Joseph Goldstein and Ali Watkins",
      "description" =>
        "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
      "fb:app_id" => "9869919170",
      "image" =>
        "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
      "msapplication-starturl" => "https://www.nytimes.com",
      "news_keywords" =>
        "NYPD,Juvenile delinquency,Facial Recognition,Privacy,Government Surveillance,Police,Civil Rights,NYC",
      "nyt_uri" => "nyt://article/9da58246-2495-505f-9abd-b5fda8e67b56",
      "og:description" =>
        "With little oversight, the N.Y.P.D. has been using powerful surveillance technology on photos of children and teenagers.",
      "og:image" =>
        "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-facebookJumbo.jpg",
      "og:title" =>
        "She Was Arrested at 14. Then Her Photo Went to a Facial Recognition Database.",
      "og:type" => "article",
      "og:url" =>
        "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
      "pdate" => "20190801",
      "pubp_event_id" => "pubp://event/47a657bafa8a476bb36832f90ee5ac6e",
      "robots" => "noarchive",
      "thumbnail" =>
        "https://static01.nyt.com/images/2019/08/01/nyregion/01nypd-juveniles-promo/01nypd-juveniles-promo-thumbStandard.jpg",
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
      "url" =>
        "https://www.nytimes.com/2019/08/01/nyregion/nypd-facial-recognition-children-teenagers.html",
      "viewport" => "width=device-width, initial-scale=1, maximum-scale=1"
    }

    assert MetaTags.parse(html) == expected
  end
end
