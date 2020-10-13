# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.FeedTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Providers.Feed

  test "it renders a link to user's atom feed" do
    user = insert(:user, nickname: "lain")

    assert Feed.build_tags(%{user: user}) == [
             {:link,
              [rel: "alternate", type: "application/atom+xml", href: "/users/lain/feed.atom"], []}
           ]
  end
end
