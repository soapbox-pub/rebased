# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.TagControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  clear_config([:feed])

  test "gets a feed", %{conn: conn} do
    Pleroma.Config.put(
      [:feed, :post_title],
      %{max_length: 10, omission: "..."}
    )

    user = insert(:user)
    {:ok, _activity1} = Pleroma.Web.CommonAPI.post(user, %{"status" => "yeah #PleromaArt"})

    {:ok, _activity2} =
      Pleroma.Web.CommonAPI.post(user, %{"status" => "42 This is :moominmamma #PleromaArt"})

    {:ok, _activity3} = Pleroma.Web.CommonAPI.post(user, %{"status" => "This is :moominmamma"})

    assert conn
           |> put_req_header("content-type", "application/atom+xml")
           |> get("/tags/pleromaart.rss")
           |> response(200)
  end
end
