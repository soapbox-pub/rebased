defmodule Pleroma.Web.MastodonAPI.TagController do
  @moduledoc "Hashtag routes for mastodon API"
  use Pleroma.Web, :controller

  alias Pleroma.Hashtag
  alias Pleroma.Pagination
  alias Pleroma.User

  import Pleroma.Web.ControllerHelper,
    only: [
      add_link_headers: 2
    ]

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["read"]} when action in [:show]
  )

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["read:follows"]} when action in [:show_followed]
  )

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["write:follows"]} when action in [:follow, :unfollow]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.TagOperation

  def show(conn, %{id: id}) do
    with %Hashtag{} = hashtag <- Hashtag.get_by_name(id) do
      render(conn, "show.json", tag: hashtag, for_user: conn.assigns.user)
    else
      _ -> conn |> render_error(:not_found, "Hashtag not found")
    end
  end

  def follow(conn, %{id: id}) do
    with %Hashtag{} = hashtag <- Hashtag.get_by_name(id),
         %User{} = user <- conn.assigns.user,
         {:ok, _} <-
           User.follow_hashtag(user, hashtag) do
      render(conn, "show.json", tag: hashtag, for_user: user)
    else
      _ -> render_error(conn, :not_found, "Hashtag not found")
    end
  end

  def unfollow(conn, %{id: id}) do
    with %Hashtag{} = hashtag <- Hashtag.get_by_name(id),
         %User{} = user <- conn.assigns.user,
         {:ok, _} <-
           User.unfollow_hashtag(user, hashtag) do
      render(conn, "show.json", tag: hashtag, for_user: user)
    else
      _ -> render_error(conn, :not_found, "Hashtag not found")
    end
  end

  def show_followed(conn, params) do
    with %{assigns: %{user: %User{} = user}} <- conn do
      params = Map.put(params, :id_type, :integer)

      hashtags =
        user
        |> User.HashtagFollow.followed_hashtags_query()
        |> Pagination.fetch_paginated(params)

      conn
      |> add_link_headers(hashtags)
      |> render("index.json", tags: hashtags, for_user: user)
    end
  end
end
