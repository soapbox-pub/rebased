# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.UserController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.ActivityPubController
  alias Pleroma.Web.Feed.FeedView

  plug(Pleroma.Web.Plugs.SetFormatPlug when action in [:feed_redirect])

  action_fallback(:errors)

  def feed_redirect(%{assigns: %{format: "html"}} = conn, %{"nickname" => nickname}) do
    with {_, %User{} = user} <- {:fetch_user, User.get_cached_by_nickname_or_id(nickname)} do
      Pleroma.Web.Fallback.RedirectController.redirector_with_meta(conn, %{user: user})
    else
      _ -> Pleroma.Web.Fallback.RedirectController.redirector(conn, nil)
    end
  end

  def feed_redirect(%{assigns: %{format: format}} = conn, _params)
      when format in ["json", "activity+json"] do
    ActivityPubController.call(conn, :user)
  end

  def feed_redirect(conn, %{"nickname" => nickname}) do
    with {_, %User{} = user} <- {:fetch_user, User.get_cached_by_nickname(nickname)} do
      redirect(conn, external: "#{Routes.user_feed_url(conn, :feed, user.nickname)}.atom")
    end
  end

  def feed(conn, %{"nickname" => nickname} = params) do
    format = get_format(conn)

    format =
      if format in ["atom", "rss"] do
        format
      else
        "atom"
      end

    with {_, %User{local: true} = user} <- {:fetch_user, User.get_cached_by_nickname(nickname)},
         {_, :visible} <- {:visibility, User.visible_for(user, _reading_user = nil)} do
      activities =
        %{
          type: ["Create"],
          actor_id: user.ap_id
        }
        |> Pleroma.Maps.put_if_present(:max_id, params["max_id"])
        |> ActivityPub.fetch_public_or_unlisted_activities()

      conn
      |> put_resp_content_type("application/#{format}+xml")
      |> put_view(FeedView)
      |> render("user.#{format}",
        user: user,
        activities: activities,
        feed_config: Config.get([:feed])
      )
    end
  end

  def errors(conn, {:error, :not_found}) do
    render_error(conn, :not_found, "Not found")
  end

  def errors(conn, {:fetch_user, %User{local: false}}), do: errors(conn, {:error, :not_found})
  def errors(conn, {:fetch_user, nil}), do: errors(conn, {:error, :not_found})

  def errors(conn, {:visibility, _}), do: errors(conn, {:error, :not_found})

  def errors(conn, _) do
    render_error(conn, :internal_server_error, "Something went wrong")
  end
end
