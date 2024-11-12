# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.ActivityPubTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Metadata.Providers.ActivityPub

  setup do: clear_config([Pleroma.Web.Metadata, :unfurl_nsfw])

  test "it renders a link for user info" do
    user = insert(:user)
    res = ActivityPub.build_tags(%{user: user})

    assert res == [
             {:link, [rel: "alternate", type: "application/activity+json", href: user.ap_id], []}
           ]
  end

  test "it renders a link for a post" do
    user = insert(:user)
    {:ok, %{id: activity_id, object: object}} = CommonAPI.post(user, %{status: "hi"})

    result = ActivityPub.build_tags(%{object: object, user: user, activity_id: activity_id})

    assert [
             {:link,
              [rel: "alternate", type: "application/activity+json", href: object.data["id"]], []}
           ] == result
  end

  test "it returns an empty array for anything else" do
    result = ActivityPub.build_tags(%{})

    assert result == []
  end
end
