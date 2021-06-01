# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.EventHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Object.Fetcher

  test "Mobilizon Event object" do
    Tesla.Mock.mock(fn
      %{url: "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/mobilizon.org-event.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }

      %{url: "https://mobilizon.org/@tcit"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/mobilizon.org-user.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }
    end)

    assert {:ok, object} =
             Fetcher.fetch_object_from_id(
               "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"
             )

    assert object.data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]
    assert object.data["cc"] == ["https://mobilizon.org/@tcit/followers"]

    assert object.data["url"] ==
             "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"

    assert object.data["published"] == "2019-12-17T11:33:56Z"
    assert object.data["name"] == "Mobilizon Launching Party"
  end
end
