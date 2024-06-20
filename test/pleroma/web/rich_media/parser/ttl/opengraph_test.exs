# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.TTL.OpengraphTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Mox

  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.Web.RichMedia.Card

  setup do
    ConfigMock
    |> stub_with(Pleroma.Test.StaticConfig)

    clear_config([:rich_media, :enabled], true)

    :ok
  end

  test "OpenGraph TTL value is honored" do
    url = "https://reddit.com/r/somepost"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^url
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/reddit.html")}

      %{method: :head} ->
        %Tesla.Env{status: 200}
    end)

    Card.get_or_backfill_by_url(url)

    # Find the backfill job
    expected_job =
      [
        worker: "Pleroma.Workers.RichMediaWorker",
        args: %{"op" => "backfill", "url" => url}
      ]

    assert_enqueued(expected_job)

    # Run it manually
    ObanHelpers.perform_all()

    assert_enqueued(
      worker: Pleroma.Workers.RichMediaWorker,
      args: %{"op" => "expire", "url" => url}
    )
  end
end
