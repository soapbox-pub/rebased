# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ExportTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Bookmark

  test "it exports user data" do
    user = insert(:user, %{nickname: "cofe", name: "Cofe", ap_id: "http://cofe.io/users/cofe"})

    {:ok, %{object: %{data: %{"id" => id1}}} = status1} =
      CommonAPI.post(user, %{status: "status1"})

    {:ok, %{object: %{data: %{"id" => id2}}} = status2} =
      CommonAPI.post(user, %{status: "status2"})

    {:ok, %{object: %{data: %{"id" => id3}}} = status3} =
      CommonAPI.post(user, %{status: "status3"})

    CommonAPI.favorite(user, status1.id)
    CommonAPI.favorite(user, status2.id)

    Bookmark.create(user.id, status2.id)
    Bookmark.create(user.id, status3.id)

    assert {:ok, path} = Pleroma.Export.run(user)
    assert {:ok, zipfile} = :zip.zip_open(path, [:memory])
    assert {:ok, {'actor.json', json}} = :zip.zip_get('actor.json', zipfile)

    assert %{
             "@context" => [
               "https://www.w3.org/ns/activitystreams",
               "http://localhost:4001/schemas/litepub-0.1.jsonld",
               %{"@language" => "und"}
             ],
             "bookmarks" => "bookmarks.json",
             "followers" => "http://cofe.io/users/cofe/followers",
             "following" => "http://cofe.io/users/cofe/following",
             "id" => "http://cofe.io/users/cofe",
             "inbox" => "http://cofe.io/users/cofe/inbox",
             "likes" => "likes.json",
             "name" => "Cofe",
             "outbox" => "http://cofe.io/users/cofe/outbox",
             "preferredUsername" => "cofe",
             "publicKey" => %{
               "id" => "http://cofe.io/users/cofe#main-key",
               "owner" => "http://cofe.io/users/cofe"
             },
             "type" => "Person",
             "url" => "http://cofe.io/users/cofe"
           } = Jason.decode!(json)

    assert {:ok, {'outbox.json', json}} = :zip.zip_get('outbox.json', zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "outbox.json",
             "orderedItems" => [
               %{
                 "object" => %{
                   "actor" => "http://cofe.io/users/cofe",
                   "content" => "status1",
                   "type" => "Note"
                 },
                 "type" => "Create"
               },
               %{
                 "object" => %{
                   "actor" => "http://cofe.io/users/cofe",
                   "content" => "status2"
                 }
               },
               %{
                 "actor" => "http://cofe.io/users/cofe",
                 "object" => %{
                   "content" => "status3"
                 }
               }
             ],
             "totalItems" => 3,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    assert {:ok, {'likes.json', json}} = :zip.zip_get('likes.json', zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "likes.json",
             "orderedItems" => [^id1, ^id2],
             "totalItems" => 2,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    assert {:ok, {'bookmarks.json', json}} = :zip.zip_get('bookmarks.json', zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "bookmarks.json",
             "orderedItems" => [^id2, ^id3],
             "totalItems" => 2,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    :zip.zip_close(zipfile)
    File.rm!(path)
  end
end
