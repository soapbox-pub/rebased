# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.ImageHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier

  test "Hubzilla Image object" do
    Tesla.Mock.mock(fn
      %{url: "https://hub.somaton.com/channel/testc6"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/hubzilla-actor.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }
    end)

    data = File.read!("test/fixtures/hubzilla-create-image.json") |> Poison.decode!()

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert object = Object.normalize(activity, fetch: false)

    assert object.data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

    assert object.data["cc"] == ["https://hub.somaton.com/followers/testc6"]

    assert object.data["attachment"] == [
             %{
               "mediaType" => "image/jpeg",
               "type" => "Link",
               "url" => [
                 %{
                   "height" => 2200,
                   "href" =>
                     "https://hub.somaton.com/photo/452583b2-7e1f-4ac3-8334-ff666f134afe-0.jpg",
                   "mediaType" => "image/jpeg",
                   "type" => "Link",
                   "width" => 2200
                 }
               ]
             }
           ]
  end
end
