# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ResilienceTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  setup do
    # user = insert(:user)
    %{user: user, conn: conn} = oauth_access(["write", "read"])
    other_user = insert(:user)

    {:ok, post_one} = CommonAPI.post(user, %{status: "Here is a post"})
    {:ok, like} = CommonAPI.favorite(other_user, post_one.id)

    %{
      user: user,
      other_user: other_user,
      post_one: post_one,
      like: like,
      conn: conn
    }
  end

  test "after destruction of like activities, things still work", %{
    user: user,
    post_one: post,
    other_user: other_user,
    conn: conn,
    like: like
  } do
    post = Repo.get(Activity, post.id)

    # Rendering the liked status
    rendered_for_user = StatusView.render("show.json", %{activity: post, for: user})
    assert rendered_for_user.favourites_count == 1

    rendered_for_other_user = StatusView.render("show.json", %{activity: post, for: other_user})
    assert rendered_for_other_user.favourites_count == 1
    assert rendered_for_other_user.favourited

    # Getting the favourited by
    [liking_user] =
      conn
      |> get("/api/v1/statuses/#{post.id}/favourited_by")
      |> json_response(200)

    assert liking_user["id"] == other_user.id

    # We have one notification
    [notification] =
      conn
      |> get("/api/v1/notifications")
      |> json_response(200)

    assert notification["type"] == "favourite"

    # Destroying the like
    Repo.delete(like)
    post = Repo.get(Activity, post.id)

    # Rendering the liked status
    rendered_for_user = StatusView.render("show.json", %{activity: post, for: user})
    assert rendered_for_user.favourites_count == 1

    rendered_for_other_user = StatusView.render("show.json", %{activity: post, for: other_user})
    assert rendered_for_other_user.favourites_count == 1
    assert rendered_for_other_user.favourited

    # Getting the favourited by
    [liking_user] =
      conn
      |> get("/api/v1/statuses/#{post.id}/favourited_by")
      |> json_response(200)

    assert liking_user["id"] == other_user.id

    # Notification is removed

    assert [] ==
             conn
             |> get("/api/v1/notifications")
             |> json_response(200)

    # Favoriting again doesn't hurt
    {:ok, _like_two} = CommonAPI.favorite(other_user, post.id)

    post = Repo.get(Activity, post.id)

    # Rendering the liked status
    rendered_for_user = StatusView.render("show.json", %{activity: post, for: user})
    assert rendered_for_user.favourites_count == 1

    # General fallout: Can't unfavorite stuff anymore. Acceptable for remote users.
  end
end
