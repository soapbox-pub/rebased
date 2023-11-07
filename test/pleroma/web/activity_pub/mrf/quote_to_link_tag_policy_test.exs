# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.QuoteToLinkTagPolicyTest do
  alias Pleroma.Web.ActivityPub.MRF.QuoteToLinkTagPolicy

  use Pleroma.DataCase

  require Pleroma.Constants

  test "Add quote url to Link tag" do
    quote_url = "https://gleasonator.com/objects/1234"

    activity = %{
      "type" => "Create",
      "actor" => "https://gleasonator.com/users/alex",
      "object" => %{
        "type" => "Note",
        "content" => "Nice post",
        "quoteUrl" => quote_url
      }
    }

    {:ok, %{"object" => object}} = QuoteToLinkTagPolicy.filter(activity)

    assert object["tag"] == [
             %{
               "type" => "Link",
               "href" => quote_url,
               "mediaType" => Pleroma.Constants.activity_json_canonical_mime_type()
             }
           ]
  end

  test "Add quote url to Link tag, append to the end" do
    quote_url = "https://gleasonator.com/objects/1234"

    activity = %{
      "type" => "Create",
      "actor" => "https://gleasonator.com/users/alex",
      "object" => %{
        "type" => "Note",
        "content" => "Nice post",
        "quoteUrl" => quote_url,
        "tag" => [%{"type" => "Hashtag", "name" => "#foo"}]
      }
    }

    {:ok, %{"object" => object}} = QuoteToLinkTagPolicy.filter(activity)

    assert [_, tag] = object["tag"]

    assert tag == %{
             "type" => "Link",
             "href" => quote_url,
             "mediaType" => Pleroma.Constants.activity_json_canonical_mime_type()
           }
  end

  test "Bypass posts without quoteUrl" do
    activity = %{
      "type" => "Create",
      "actor" => "https://gleasonator.com/users/alex",
      "object" => %{
        "type" => "Note",
        "content" => "Nice post"
      }
    }

    assert {:ok, ^activity} = QuoteToLinkTagPolicy.filter(activity)
  end
end
