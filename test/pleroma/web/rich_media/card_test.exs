# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.CardTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase, async: true

  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.RichMedia.Card
  alias Pleroma.Workers.RichMediaWorker

  import Mox
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    ConfigMock
    |> stub_with(Pleroma.Test.StaticConfig)

    :ok
  end

  setup do: clear_config([:rich_media, :enabled], true)

  test "crawls URL in activity" do
    user = insert(:user)

    url = "https://example.com/ogp"
    url_hash = Card.url_to_hash(url)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "[test](#{url})",
        content_type: "text/markdown"
      })

    Pleroma.Web.ActivityPub.ActivityPubMock
    |> expect(:stream_out, fn ^activity -> nil end)

    assert_enqueued(
      worker: RichMediaWorker,
      args: %{"url" => url, "activity_id" => activity.id}
    )

    ObanHelpers.perform_all()

    assert %Card{url_hash: ^url_hash, fields: _} = Card.get_by_activity(activity)
  end

  test "recrawls URLs on status edits/updates" do
    original_url = "https://google.com/"
    original_url_hash = Card.url_to_hash(original_url)
    updated_url = "https://yahoo.com/"
    updated_url_hash = Card.url_to_hash(updated_url)

    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "I like this site #{original_url}"})

    # Force a backfill
    Card.get_by_activity(activity)
    ObanHelpers.perform_all()

    assert match?(
             %Card{url_hash: ^original_url_hash, fields: _},
             Card.get_by_activity(activity)
           )

    {:ok, _} = CommonAPI.update(activity, user, %{status: "I like this site #{updated_url}"})

    activity = Pleroma.Activity.get_by_id(activity.id)

    # Force a backfill
    Card.get_by_activity(activity)
    ObanHelpers.perform_all()

    assert match?(
             %Card{url_hash: ^updated_url_hash, fields: _},
             Card.get_by_activity(activity)
           )
  end
end
