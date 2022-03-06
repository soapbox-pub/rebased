# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.ArticleHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.Web.ActivityPub.Transmogrifier

  test "Pterotype (Wordpress Plugin) Article" do
    Tesla.Mock.mock(fn %{url: "https://wedistribute.org/wp-json/pterotype/v1/actor/-blog"} ->
      %Tesla.Env{
        status: 200,
        body: File.read!("test/fixtures/tesla_mock/wedistribute-user.json"),
        headers: HttpRequestMock.activitypub_object_headers()
      }
    end)

    data =
      File.read!("test/fixtures/tesla_mock/wedistribute-create-article.json") |> Jason.decode!()

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    object = Object.normalize(data["object"], fetch: false)

    assert object.data["name"] == "The end is near: Mastodon plans to drop OStatus support"

    assert object.data["summary"] ==
             "One of the largest platforms in the federated social web is dropping the protocol that it started with."

    assert object.data["url"] == "https://wedistribute.org/2019/07/mastodon-drops-ostatus/"
  end

  test "Plume Article" do
    Tesla.Mock.mock(fn
      %{url: "https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/baptiste.gelex.xyz-article.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }

      %{url: "https://baptiste.gelez.xyz/@/BaptisteGelez"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/baptiste.gelex.xyz-user.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }
    end)

    {:ok, object} =
      Fetcher.fetch_object_from_id(
        "https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/"
      )

    assert object.data["name"] == "This Month in Plume: June 2018"

    assert object.data["url"] ==
             "https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/"
  end

  test "Prismo Article" do
    Tesla.Mock.mock(fn %{url: "https://prismo.news/@mxb"} ->
      %Tesla.Env{
        status: 200,
        body: File.read!("test/fixtures/tesla_mock/https___prismo.news__mxb.json"),
        headers: HttpRequestMock.activitypub_object_headers()
      }
    end)

    data = File.read!("test/fixtures/prismo-url-map.json") |> Jason.decode!()

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
    object = Object.normalize(data["object"], fetch: false)

    assert object.data["url"] == "https://prismo.news/posts/83"
  end
end
