# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ObjectTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Tesla.Mock

  alias Pleroma.Activity
  alias Pleroma.Hashtag
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Web.CommonAPI

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "returns an object by it's AP id" do
    object = insert(:note)
    found_object = Object.get_by_ap_id(object.data["id"])

    assert object == found_object
  end

  describe "generic changeset" do
    test "it ensures uniqueness of the id" do
      object = insert(:note)
      cs = Object.change(%Object{}, %{data: %{id: object.data["id"]}})
      assert cs.valid?

      {:error, _result} = Repo.insert(cs)
    end
  end

  describe "deletion function" do
    test "deletes an object" do
      object = insert(:note)
      found_object = Object.get_by_ap_id(object.data["id"])

      assert object == found_object

      Object.delete(found_object)

      found_object = Object.get_by_ap_id(object.data["id"])

      refute object == found_object

      assert found_object.data["type"] == "Tombstone"
    end

    test "ensures cache is cleared for the object" do
      object = insert(:note)
      cached_object = Object.get_cached_by_ap_id(object.data["id"])

      assert object == cached_object

      Cachex.put(:web_resp_cache, URI.parse(object.data["id"]).path, "cofe")

      Object.delete(cached_object)

      {:ok, nil} = Cachex.get(:object_cache, "object:#{object.data["id"]}")
      {:ok, nil} = Cachex.get(:web_resp_cache, URI.parse(object.data["id"]).path)

      cached_object = Object.get_cached_by_ap_id(object.data["id"])

      refute object == cached_object

      assert cached_object.data["type"] == "Tombstone"
    end
  end

  describe "delete attachments" do
    setup do: clear_config([Pleroma.Upload])
    setup do: clear_config([:instance, :cleanup_attachments])

    test "Disabled via config" do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
      clear_config([:instance, :cleanup_attachments], false)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      user = insert(:user)

      {:ok, %Object{} = attachment} =
        Pleroma.Web.ActivityPub.ActivityPub.upload(file, actor: user.ap_id)

      %{data: %{"attachment" => [%{"url" => [%{"href" => href}]}]}} =
        note = insert(:note, %{user: user, data: %{"attachment" => [attachment.data]}})

      uploads_dir = Pleroma.Config.get!([Pleroma.Uploaders.Local, :uploads])

      path = href |> Path.dirname() |> Path.basename()

      assert {:ok, ["an_image.jpg"]} == File.ls("#{uploads_dir}/#{path}")

      Object.delete(note)

      ObanHelpers.perform(all_enqueued(worker: Pleroma.Workers.AttachmentsCleanupWorker))

      assert Object.get_by_id(note.id).data["deleted"]
      refute Object.get_by_id(attachment.id) == nil

      assert {:ok, ["an_image.jpg"]} == File.ls("#{uploads_dir}/#{path}")
    end

    test "in subdirectories" do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
      clear_config([:instance, :cleanup_attachments], true)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      user = insert(:user)

      {:ok, %Object{} = attachment} =
        Pleroma.Web.ActivityPub.ActivityPub.upload(file, actor: user.ap_id)

      %{data: %{"attachment" => [%{"url" => [%{"href" => href}]}]}} =
        note = insert(:note, %{user: user, data: %{"attachment" => [attachment.data]}})

      uploads_dir = Pleroma.Config.get!([Pleroma.Uploaders.Local, :uploads])

      path = href |> Path.dirname() |> Path.basename()

      assert {:ok, ["an_image.jpg"]} == File.ls("#{uploads_dir}/#{path}")

      Object.delete(note)

      ObanHelpers.perform(all_enqueued(worker: Pleroma.Workers.AttachmentsCleanupWorker))

      assert Object.get_by_id(note.id).data["deleted"]
      assert Object.get_by_id(attachment.id) == nil

      assert {:ok, []} == File.ls("#{uploads_dir}/#{path}")
    end

    test "with dedupe enabled" do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
      clear_config([Pleroma.Upload, :filters], [Pleroma.Upload.Filter.Dedupe])
      clear_config([:instance, :cleanup_attachments], true)

      uploads_dir = Pleroma.Config.get!([Pleroma.Uploaders.Local, :uploads])

      File.mkdir_p!(uploads_dir)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      user = insert(:user)

      {:ok, %Object{} = attachment} =
        Pleroma.Web.ActivityPub.ActivityPub.upload(file, actor: user.ap_id)

      %{data: %{"attachment" => [%{"url" => [%{"href" => href}]}]}} =
        note = insert(:note, %{user: user, data: %{"attachment" => [attachment.data]}})

      filename = Path.basename(href)

      assert {:ok, files} = File.ls(uploads_dir)
      assert filename in files

      Object.delete(note)

      ObanHelpers.perform(all_enqueued(worker: Pleroma.Workers.AttachmentsCleanupWorker))

      assert Object.get_by_id(note.id).data["deleted"]
      assert Object.get_by_id(attachment.id) == nil
      assert {:ok, files} = File.ls(uploads_dir)
      refute filename in files
    end

    test "with objects that have legacy data.url attribute" do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
      clear_config([:instance, :cleanup_attachments], true)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      user = insert(:user)

      {:ok, %Object{} = attachment} =
        Pleroma.Web.ActivityPub.ActivityPub.upload(file, actor: user.ap_id)

      {:ok, %Object{}} = Object.create(%{url: "https://google.com", actor: user.ap_id})

      %{data: %{"attachment" => [%{"url" => [%{"href" => href}]}]}} =
        note = insert(:note, %{user: user, data: %{"attachment" => [attachment.data]}})

      uploads_dir = Pleroma.Config.get!([Pleroma.Uploaders.Local, :uploads])

      path = href |> Path.dirname() |> Path.basename()

      assert {:ok, ["an_image.jpg"]} == File.ls("#{uploads_dir}/#{path}")

      Object.delete(note)

      ObanHelpers.perform(all_enqueued(worker: Pleroma.Workers.AttachmentsCleanupWorker))

      assert Object.get_by_id(note.id).data["deleted"]
      assert Object.get_by_id(attachment.id) == nil

      assert {:ok, []} == File.ls("#{uploads_dir}/#{path}")
    end

    test "With custom base_url" do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
      clear_config([Pleroma.Upload, :base_url], "https://sub.domain.tld/dir/")
      clear_config([:instance, :cleanup_attachments], true)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      user = insert(:user)

      {:ok, %Object{} = attachment} =
        Pleroma.Web.ActivityPub.ActivityPub.upload(file, actor: user.ap_id)

      %{data: %{"attachment" => [%{"url" => [%{"href" => href}]}]}} =
        note = insert(:note, %{user: user, data: %{"attachment" => [attachment.data]}})

      uploads_dir = Pleroma.Config.get!([Pleroma.Uploaders.Local, :uploads])

      path = href |> Path.dirname() |> Path.basename()

      assert {:ok, ["an_image.jpg"]} == File.ls("#{uploads_dir}/#{path}")

      Object.delete(note)

      ObanHelpers.perform(all_enqueued(worker: Pleroma.Workers.AttachmentsCleanupWorker))

      assert Object.get_by_id(note.id).data["deleted"]
      assert Object.get_by_id(attachment.id) == nil

      assert {:ok, []} == File.ls("#{uploads_dir}/#{path}")
    end
  end

  describe "normalizer" do
    @url "http://mastodon.example.org/@admin/99541947525187367"
    test "does not fetch unknown objects by default" do
      assert nil == Object.normalize(@url)
    end

    test "fetches unknown objects when fetch is explicitly true" do
      %Object{} = object = Object.normalize(@url, fetch: true)

      assert object.data["url"] == @url
    end

    test "does not fetch unknown objects when fetch is false" do
      assert is_nil(
               Object.normalize(@url,
                 fetch: false
               )
             )
    end
  end

  describe "get_by_id_and_maybe_refetch" do
    setup do
      mock(fn
        %{method: :get, url: "https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d"} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/tesla_mock/poll_original.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        env ->
          apply(HttpRequestMock, :request, [env])
      end)

      mock_modified = fn resp ->
        mock(fn
          %{method: :get, url: "https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d"} ->
            resp

          env ->
            apply(HttpRequestMock, :request, [env])
        end)
      end

      on_exit(fn -> mock(fn env -> apply(HttpRequestMock, :request, [env]) end) end)

      [mock_modified: mock_modified]
    end

    test "refetches if the time since the last refetch is greater than the interval", %{
      mock_modified: mock_modified
    } do
      %Object{} =
        object =
        Object.normalize("https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d",
          fetch: true
        )

      Object.set_cache(object)

      assert Enum.at(object.data["oneOf"], 0)["replies"]["totalItems"] == 4
      assert Enum.at(object.data["oneOf"], 1)["replies"]["totalItems"] == 0

      mock_modified.(%Tesla.Env{
        status: 200,
        body: File.read!("test/fixtures/tesla_mock/poll_modified.json"),
        headers: HttpRequestMock.activitypub_object_headers()
      })

      updated_object = Object.get_by_id_and_maybe_refetch(object.id, interval: -1)
      object_in_cache = Object.get_cached_by_ap_id(object.data["id"])
      assert updated_object == object_in_cache
      assert Enum.at(updated_object.data["oneOf"], 0)["replies"]["totalItems"] == 8
      assert Enum.at(updated_object.data["oneOf"], 1)["replies"]["totalItems"] == 3
    end

    test "returns the old object if refetch fails", %{mock_modified: mock_modified} do
      %Object{} =
        object =
        Object.normalize("https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d",
          fetch: true
        )

      Object.set_cache(object)

      assert Enum.at(object.data["oneOf"], 0)["replies"]["totalItems"] == 4
      assert Enum.at(object.data["oneOf"], 1)["replies"]["totalItems"] == 0

      assert capture_log(fn ->
               mock_modified.(%Tesla.Env{status: 404, body: ""})

               updated_object = Object.get_by_id_and_maybe_refetch(object.id, interval: -1)
               object_in_cache = Object.get_cached_by_ap_id(object.data["id"])
               assert updated_object == object_in_cache
               assert Enum.at(updated_object.data["oneOf"], 0)["replies"]["totalItems"] == 4
               assert Enum.at(updated_object.data["oneOf"], 1)["replies"]["totalItems"] == 0
             end) =~
               "[error] Couldn't refresh https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d"
    end

    test "does not refetch if the time since the last refetch is greater than the interval", %{
      mock_modified: mock_modified
    } do
      %Object{} =
        object =
        Object.normalize("https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d",
          fetch: true
        )

      Object.set_cache(object)

      assert Enum.at(object.data["oneOf"], 0)["replies"]["totalItems"] == 4
      assert Enum.at(object.data["oneOf"], 1)["replies"]["totalItems"] == 0

      mock_modified.(%Tesla.Env{
        status: 200,
        body: File.read!("test/fixtures/tesla_mock/poll_modified.json"),
        headers: HttpRequestMock.activitypub_object_headers()
      })

      updated_object = Object.get_by_id_and_maybe_refetch(object.id, interval: 100)
      object_in_cache = Object.get_cached_by_ap_id(object.data["id"])
      assert updated_object == object_in_cache
      assert Enum.at(updated_object.data["oneOf"], 0)["replies"]["totalItems"] == 4
      assert Enum.at(updated_object.data["oneOf"], 1)["replies"]["totalItems"] == 0
    end

    test "preserves internal fields on refetch", %{mock_modified: mock_modified} do
      %Object{} =
        object =
        Object.normalize("https://patch.cx/objects/9a172665-2bc5-452d-8428-2361d4c33b1d",
          fetch: true
        )

      Object.set_cache(object)

      assert Enum.at(object.data["oneOf"], 0)["replies"]["totalItems"] == 4
      assert Enum.at(object.data["oneOf"], 1)["replies"]["totalItems"] == 0

      user = insert(:user)
      activity = Activity.get_create_by_object_ap_id(object.data["id"])
      {:ok, activity} = CommonAPI.favorite(user, activity.id)
      object = Object.get_by_ap_id(activity.data["object"])

      assert object.data["like_count"] == 1

      mock_modified.(%Tesla.Env{
        status: 200,
        body: File.read!("test/fixtures/tesla_mock/poll_modified.json"),
        headers: HttpRequestMock.activitypub_object_headers()
      })

      updated_object = Object.get_by_id_and_maybe_refetch(object.id, interval: -1)
      object_in_cache = Object.get_cached_by_ap_id(object.data["id"])
      assert updated_object == object_in_cache
      assert Enum.at(updated_object.data["oneOf"], 0)["replies"]["totalItems"] == 8
      assert Enum.at(updated_object.data["oneOf"], 1)["replies"]["totalItems"] == 3

      assert updated_object.data["like_count"] == 1
    end
  end

  describe ":hashtags association" do
    test "Hashtag records are created with Object record and updated on its change" do
      user = insert(:user)

      {:ok, %{object: object}} =
        CommonAPI.post(user, %{status: "some text #hashtag1 #hashtag2 ..."})

      assert [%Hashtag{name: "hashtag1"}, %Hashtag{name: "hashtag2"}] =
               Enum.sort_by(object.hashtags, & &1.name)

      {:ok, object} = Object.update_data(object, %{"tag" => []})

      assert [] = object.hashtags

      object = Object.get_by_id(object.id) |> Repo.preload(:hashtags)
      assert [] = object.hashtags

      {:ok, object} = Object.update_data(object, %{"tag" => ["abc", "def"]})

      assert [%Hashtag{name: "abc"}, %Hashtag{name: "def"}] =
               Enum.sort_by(object.hashtags, & &1.name)
    end
  end
end
