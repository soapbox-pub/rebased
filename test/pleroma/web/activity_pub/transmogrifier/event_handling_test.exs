# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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
    assert object.data["startTime"] == "2019-12-18T13:00:00Z"
    assert object.data["endTime"] == "2019-12-18T14:00:00Z"

    assert object.data["location"] == %{
             "address" => %{
               "addressCountry" => "France",
               "addressLocality" => "Nantes",
               "addressRegion" => "Pays de la Loire",
               "type" => "PostalAddress"
             },
             "name" => "Cour du Château des Ducs de Bretagne",
             "type" => "Place"
           }
  end

  test "Gancio Event object" do
    Tesla.Mock.mock(fn
      %{url: "https://demo.gancio.org/federation/m/1"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/gancio-event.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }

      %{url: "https://demo.gancio.org/federation/u/customized"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/gancio-user.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }
    end)

    assert {:ok, object} = Fetcher.fetch_object_from_id("https://demo.gancio.org/federation/m/1")

    assert object.data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]
    # assert object.data["cc"] == ["https://demo.gancio.org/federation/u/customized/followers"]

    assert object.data["url"] == "https://demo.gancio.org/event/demo-event"

    assert object.data["published"] == "2021-07-01T22:33:36.543Z"
    assert object.data["name"] == "Demo event"
    assert object.data["startTime"] == "2021-07-14T15:30:57.000Z"
    assert object.data["endTime"] == "2021-07-14T16:30:57.000Z"

    assert object.data["location"] == %{
             "address" => %{
               "streetAddress" => "Piazza del Colosseo, Rome",
               "type" => "PostalAddress"
             },
             "name" => "Colosseo",
             "type" => "Place"
           }
  end
end
