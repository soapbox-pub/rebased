defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo, Object, Activity}
  alias Pleroma.Web.ActivityPub.{ObjectView, UserView, Transmogrifier}
  alias Pleroma.Web.ActivityPub.ActivityPub

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
    # File.write("/tmp/incoming.json", Poison.encode!(params))
    with {:ok, _user} <- ap_enabled_actor(params["actor"]),
         nil <- Activity.get_by_ap_id(params["id"]),
         {:ok, activity} <- Transmogrifier.handle_incoming(params) do
      json(conn, "ok")
    else
      %Activity{} ->
        Logger.info("Already had #{params["id"]}")
        json(conn, "ok")
      e ->
        # Just drop those for now
        Logger.info("Unhandled activity")
        Logger.info(Poison.encode!(params, [pretty: 2]))
        json(conn, "ok")
    end
  end

  def inbox(conn, params) do
    Logger.info("Signature error.")
    Logger.info(inspect(conn.req_headers))
    json(conn, "ok")
  end

  def ap_enabled_actor(id) do
    user = User.get_by_ap_id(id)
    if User.ap_enabled?(user) do
      {:ok, user}
    else
      ActivityPub.make_user_from_ap_id(id)
    end
  end

  def errors(conn, _e) do
    conn
    |> put_status(500)
    |> json("error")
  end
end
