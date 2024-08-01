# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.BackfillTest do
  use Pleroma.DataCase

  alias Pleroma.Web.RichMedia.Backfill
  alias Pleroma.Web.RichMedia.Card

  import Mox

  setup_all do: clear_config([:rich_media, :enabled], true)

  test "sets a negative cache entry for an error" do
    url = "https://bad.example.com/"
    url_hash = Card.url_to_hash(url)

    Tesla.Mock.mock(fn %{url: ^url} -> :error end)

    Pleroma.CachexMock
    |> expect(:put, fn :rich_media_cache, ^url_hash, :error, ttl: _ -> {:ok, true} end)

    Backfill.run(%{"url" => url})
  end
end
