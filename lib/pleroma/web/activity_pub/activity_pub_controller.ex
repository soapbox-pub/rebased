defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo, Object}
  alias Pleroma.Web.ActivityPub.{ObjectView, UserView}
  alias Pleroma.Web.ActivityPub.ActivityPub

  def user(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      json(conn, UserView.render("user.json", %{user: user}))
    end
  end

  def object(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :object, uuid),
         %Object{} = object <- Object.get_cached_by_ap_id(ap_id) do
      json(conn, ObjectView.render("object.json", %{object: object}))
    end
  end

  def inbox(conn, params) do
    {:ok, activity} = ActivityPub.insert(params, false)
    json(conn, "ok")
  end
end
