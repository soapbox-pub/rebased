# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidator
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

    test "a note from factory validates" do
      note = insert(:note)
      %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note.data)
    end
  end

  describe "Note with history" do
    setup do
      user = insert(:user)
      {:ok, activity} = Pleroma.Web.CommonAPI.post(user, %{status: "mew mew :dinosaur:"})
      {:ok, edit} = Pleroma.Web.CommonAPI.update(user, activity, %{status: "edited :blank:"})

      {:ok, %{"object" => external_rep}} =
        Pleroma.Web.ActivityPub.Transmogrifier.prepare_outgoing(edit.data)

      %{external_rep: external_rep}
    end

    test "edited note", %{external_rep: external_rep} do
      assert %{"formerRepresentations" => %{"orderedItems" => [%{"tag" => [_]}]}} = external_rep

      {:ok, validate_res, []} = ObjectValidator.validate(external_rep, [])

      assert %{"formerRepresentations" => %{"orderedItems" => [%{"emoji" => %{"dinosaur" => _}}]}} =
               validate_res
    end

    test "edited note, badly-formed formerRepresentations", %{external_rep: external_rep} do
      external_rep = Map.put(external_rep, "formerRepresentations", %{})

      assert {:error, _} = ObjectValidator.validate(external_rep, [])
    end

    test "edited note, badly-formed history item", %{external_rep: external_rep} do
      history_item =
        Enum.at(external_rep["formerRepresentations"]["orderedItems"], 0)
        |> Map.put("type", "Foo")

      external_rep =
        put_in(
          external_rep,
          ["formerRepresentations", "orderedItems"],
          [history_item]
        )

      assert {:error, _} = ObjectValidator.validate(external_rep, [])
    end
  end

  test "a Note from Roadhouse validates" do
    insert(:user, ap_id: "https://macgirvin.com/channel/mike")

    %{"object" => note} =
      "test/fixtures/roadhouse-create-activity.json"
      |> File.read!()
      |> Jason.decode!()

    %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note)
  end

  test "a note with an attachment should work", _ do
    insert(:user, %{ap_id: "https://owncast.localhost.localdomain/federation/user/streamer"})

    note =
      "test/fixtures/owncast-note-with-attachment.json"
      |> File.read!()
      |> Jason.decode!()

    %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note)
  end

  test "a Note without replies/first/items validates" do
    insert(:user, ap_id: "https://mastodon.social/users/emelie")

    note =
      "test/fixtures/tesla_mock/status.emelie.json"
      |> File.read!()
      |> Jason.decode!()
      |> pop_in(["replies", "first", "items"])
      |> elem(1)

    %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note)
  end

  describe "Note language" do
    test "it detects language from JSON-LD context" do
      user = insert(:user)

      note_activity = %{
        "@context" => ["https://www.w3.org/ns/activitystreams", %{"@language" => "pl"}],
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [],
        "type" => "Create",
        "object" => %{
          "to" => ["https://www.w3.org/ns/activitystreams#Public"],
          "cc" => [],
          "id" => Utils.generate_object_id(),
          "type" => "Note",
          "content" => "Szczęść Boże",
          "attributedTo" => user.ap_id
        },
        "actor" => user.ap_id
      }

      {:ok, object} =
        ArticleNotePageValidator.cast_and_apply(note_activity["object"],
          activity_data: note_activity
        )

      assert object.language == "pl"
    end

    test "it detects language from contentMap" do
      user = insert(:user)

      note = %{
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [],
        "id" => Utils.generate_object_id(),
        "type" => "Note",
        "content" => "Szczęść Boże",
        "contentMap" => %{
          "de" => "Gott segne",
          "pl" => "Szczęść Boże"
        },
        "attributedTo" => user.ap_id
      }

      {:ok, object} = ArticleNotePageValidator.cast_and_apply(note)

      assert object.language == "pl"
    end

    test "it adds contentMap if language is specified" do
      user = insert(:user)

      note = %{
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [],
        "id" => Utils.generate_object_id(),
        "type" => "Note",
        "content" => "тест",
        "language" => "uk",
        "attributedTo" => user.ap_id
      }

      {:ok, object} = ArticleNotePageValidator.cast_and_apply(note)

      assert object.contentMap == %{
               "uk" => "тест"
             }
    end
  end
end
