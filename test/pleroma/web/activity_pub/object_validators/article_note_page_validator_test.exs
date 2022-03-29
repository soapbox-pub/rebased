# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidator
  alias Pleroma.Web.ActivityPub.Utils

  import Pleroma.Factory

  describe "Notes" do
    setup do
      user = insert(:user)

      note = %{
        "id" => Utils.generate_activity_id(),
        "type" => "Note",
        "actor" => user.ap_id,
        "to" => [user.follower_address],
        "cc" => [],
        "content" => "Hellow this is content.",
        "context" => "xxx",
        "summary" => "a post"
      }

      %{user: user, note: note}
    end

    test "a basic note validates", %{note: note} do
      %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note)
    end
  end

  test "Fedibird quote post" do
    insert(:user, ap_id: "https://fedibird.com/users/noellabo")

    data = File.read!("test/fixtures/quote_post/fedibird_quote_post.json") |> Jason.decode!()
    cng = ArticleNotePageValidator.cast_and_validate(data)

    assert cng.valid?
    assert cng.changes.quoteUrl == "https://misskey.io/notes/8vsn2izjwh"
  end

  test "Fedibird quote post with quoteUri field" do
    insert(:user, ap_id: "https://fedibird.com/users/noellabo")

    data = File.read!("test/fixtures/quote_post/fedibird_quote_uri.json") |> Jason.decode!()
    cng = ArticleNotePageValidator.cast_and_validate(data)

    assert cng.valid?
    assert cng.changes.quoteUrl == "https://fedibird.com/users/yamako/statuses/107699333438289729"
  end

  test "Misskey quote post" do
    insert(:user, ap_id: "https://misskey.io/users/7rkrarq81i")

    data = File.read!("test/fixtures/quote_post/misskey_quote_post.json") |> Jason.decode!()
    cng = ArticleNotePageValidator.cast_and_validate(data)

    assert cng.valid?
    assert cng.changes.quoteUrl == "https://misskey.io/notes/8vs6wxufd0"
  end

  test "a Note from Roadhouse validates" do
    insert(:user, ap_id: "https://macgirvin.com/channel/mike")

    %{"object" => note} =
      "test/fixtures/roadhouse-create-activity.json"
      |> File.read!()
      |> Jason.decode!()

    %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note)
  end
end
