# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.InlineQuotePolicyTest do
  alias Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy
  use Pleroma.DataCase

  test "adds quote URL to post content" do
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

    {:ok, %{"object" => %{"content" => filtered}}} = InlineQuotePolicy.filter(activity)

    assert filtered ==
             "Nice post<span class=\"quote-inline\"><br/><br/>RT: <a href=\"https://gleasonator.com/objects/1234\">https://gleasonator.com/objects/1234</a></span>"
  end

  test "doesn't add line breaks to markdown posts" do
    quote_url = "https://gleasonator.com/objects/1234"

    activity = %{
      "type" => "Create",
      "actor" => "https://gleasonator.com/users/alex",
      "object" => %{
        "type" => "Note",
        "content" => "<p>Nice post</p>",
        "quoteUrl" => quote_url
      }
    }

    {:ok, %{"object" => %{"content" => filtered}}} = InlineQuotePolicy.filter(activity)

    assert filtered ==
             "<p>Nice post<span class=\"quote-inline\"><br/><br/>RT: <a href=\"https://gleasonator.com/objects/1234\">https://gleasonator.com/objects/1234</a></span></p>"
  end

  test "ignores Misskey quote posts" do
    object = File.read!("test/fixtures/quote_post/misskey_quote_post.json") |> Jason.decode!()

    activity = %{
      "type" => "Create",
      "actor" => "https://misskey.io/users/7rkrarq81i",
      "object" => object
    }

    {:ok, filtered} = InlineQuotePolicy.filter(activity)
    assert filtered == activity
  end

  test "ignores Fedibird quote posts" do
    object = File.read!("test/fixtures/quote_post/fedibird_quote_post.json") |> Jason.decode!()

    # Normally the ObjectValidator will fix this before it reaches MRF
    object = Map.put(object, "quoteUrl", object["quoteURL"])

    activity = %{
      "type" => "Create",
      "actor" => "https://fedibird.com/users/noellabo",
      "object" => object
    }

    {:ok, filtered} = InlineQuotePolicy.filter(activity)
    assert filtered == activity
  end

  test "skips objects which already have an .inline-quote span" do
    object =
      File.read!("test/fixtures/quote_post/fedibird_quote_mismatched.json") |> Jason.decode!()

    # Normally the ObjectValidator will fix this before it reaches MRF
    object = Map.put(object, "quoteUrl", object["quoteUri"])

    activity = %{
      "type" => "Create",
      "actor" => "https://fedibird.com/users/noellabo",
      "object" => object
    }

    {:ok, filtered} = InlineQuotePolicy.filter(activity)
    assert filtered == activity
  end
end
