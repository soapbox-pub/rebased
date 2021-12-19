# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.VideoHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.Web.ActivityPub.Transmogrifier

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "skip converting the content when it is nil" do
    data =
      File.read!("test/fixtures/tesla_mock/framatube.org-video.json")
      |> Jason.decode!()
      |> Kernel.put_in(["object", "content"], nil)

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert object = Object.normalize(activity, fetch: false)

    assert object.data["content"] == nil
  end

  test "it converts content of object to html" do
    data = File.read!("test/fixtures/tesla_mock/framatube.org-video.json") |> Jason.decode!()

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert object = Object.normalize(activity, fetch: false)

    assert object.data["content"] ==
             "<p>Après avoir mené avec un certain succès la campagne « Dégooglisons Internet » en 2014, l’association Framasoft annonce fin 2019 arrêter progressivement un certain nombre de ses services alternatifs aux GAFAM. Pourquoi ?</p><p>Transcription par @aprilorg ici : <a href=\"https://www.april.org/deframasoftisons-internet-pierre-yves-gosset-framasoft\">https://www.april.org/deframasoftisons-internet-pierre-yves-gosset-framasoft</a></p>"
  end

  test "it remaps video URLs as attachments if necessary" do
    {:ok, object} =
      Fetcher.fetch_object_from_id(
        "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
      )

    assert object.data["url"] ==
             "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"

    assert object.data["attachment"] == [
             %{
               "type" => "Link",
               "mediaType" => "video/mp4",
               "url" => [
                 %{
                   "href" =>
                     "https://peertube.moe/static/webseed/df5f464b-be8d-46fb-ad81-2d4c2d1630e3-480.mp4",
                   "mediaType" => "video/mp4",
                   "type" => "Link",
                   "width" => 480
                 }
               ]
             }
           ]

    data = File.read!("test/fixtures/tesla_mock/framatube.org-video.json") |> Jason.decode!()

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert object = Object.normalize(activity, fetch: false)

    assert object.data["attachment"] == [
             %{
               "type" => "Link",
               "mediaType" => "video/mp4",
               "url" => [
                 %{
                   "href" =>
                     "https://framatube.org/static/webseed/6050732a-8a7a-43d4-a6cd-809525a1d206-1080.mp4",
                   "mediaType" => "video/mp4",
                   "type" => "Link",
                   "height" => 1080
                 }
               ]
             }
           ]

    assert object.data["url"] ==
             "https://framatube.org/videos/watch/6050732a-8a7a-43d4-a6cd-809525a1d206"
  end

  test "it works for peertube videos with only their mpegURL map" do
    data =
      File.read!("test/fixtures/peertube/video-object-mpegURL-only.json")
      |> Jason.decode!()

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert object = Object.normalize(activity, fetch: false)

    assert object.data["attachment"] == [
             %{
               "type" => "Link",
               "mediaType" => "video/mp4",
               "url" => [
                 %{
                   "href" =>
                     "https://peertube.stream/static/streaming-playlists/hls/abece3c3-b9c6-47f4-8040-f3eed8c602e6/abece3c3-b9c6-47f4-8040-f3eed8c602e6-1080-fragmented.mp4",
                   "mediaType" => "video/mp4",
                   "type" => "Link",
                   "height" => 1080
                 }
               ]
             }
           ]

    assert object.data["url"] ==
             "https://peertube.stream/videos/watch/abece3c3-b9c6-47f4-8040-f3eed8c602e6"
  end
end
