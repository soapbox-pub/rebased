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
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("user.json", %{user: user}))
    end
  end

  def object(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :object, uuid),
         %Object{} = object <- Object.get_cached_by_ap_id(ap_id) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(ObjectView.render("object.json", %{object: object}))
    end
  end

  # TODO: Ensure that this inbox is a recipient of the message
  def inbox(%{assigns: %{valid_signature: true}} = conn, params) do
    Federator.enqueue(:incoming_ap_doc, params)
    json(conn, "ok")
  end

  def inbox(conn, params) do
    headers = Enum.into(conn.req_headers, %{})
    if !(String.contains?(headers["signature"] || "", params["actor"])) do
      Logger.info("Signature not from author, relayed message, ignoring.")
    else
      Logger.info("Signature error.")
      Logger.info("Could not validate #{params["actor"]}")
      Logger.info(inspect(conn.req_headers))
    end

    json(conn, "ok")
  end

  def errors(conn, _e) do
    conn
    |> put_status(500)
    |> json("error")
  end
end
