# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.PageHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Object.Fetcher

  test "Lemmy Page" do
    Tesla.Mock.mock(fn
      %{url: "https://enterprise.lemmy.ml/post/3"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/activity+json"}],
          body: File.read!("test/fixtures/tesla_mock/lemmy-page.json")
        }

      %{url: "https://enterprise.lemmy.ml/u/nutomic"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/activity+json"}],
          body: File.read!("test/fixtures/tesla_mock/lemmy-user.json")
        }
    end)

    {:ok, object} = Fetcher.fetch_object_from_id("https://enterprise.lemmy.ml/post/3")

    assert object.data["summary"] == "Hello Federation!"
    assert object.data["published"] == "2020-09-14T15:03:11.909105Z"

    # WAT
    assert object.data["url"] == "https://enterprise.lemmy.ml/pictrs/image/US52d9DPvf.jpg"
  end
end
