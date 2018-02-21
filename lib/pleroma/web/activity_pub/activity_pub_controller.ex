defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo, Object, Activity}
  alias Pleroma.Web.ActivityPub.{ObjectView, UserView, Transmogrifier}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Federator

  require Logger

  action_fallback :errors

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

  # TODO: Ensure that this inbox is a recipient of the message
  def inbox(%{assigns: %{valid_signature: true}} = conn, params) do
    Federator.enqueue(:incoming_ap_doc, params)
    json(conn, "ok")
  end

  def inbox(conn, params) do
    Logger.info("Signature error.")
    Logger.info(inspect(conn.req_headers))
    json(conn, "ok")
  end

  def errors(conn, _e) do
    conn
    |> put_status(500)
    |> json("error")
  end
end
