defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Object}
  alias Pleroma.Web.ActivityPub.{ObjectView, UserView}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.Federator

  require Logger

  action_fallback(:errors)

  def user(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("user.json", %{user: user}))
    else
      nil -> {:error, :not_found}
    end
  end

  def object(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :object, uuid),
         %Object{} = object <- Object.get_cached_by_ap_id(ap_id),
         {_, true} <- {:public?, ActivityPub.is_public?(object)} do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(ObjectView.render("object.json", %{object: object}))
    else
      {:public?, false} ->
        {:error, :not_found}
    end
  end

  def following(conn, %{"nickname" => nickname, "page" => page}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("following.json", %{user: user, page: page}))
    end
  end

  def following(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("following.json", %{user: user}))
    end
  end

  def followers(conn, %{"nickname" => nickname, "page" => page}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("followers.json", %{user: user, page: page}))
    end
  end

  def followers(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("followers.json", %{user: user}))
    end
  end

  def outbox(conn, %{"nickname" => nickname, "max_id" => max_id}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("outbox.json", %{user: user, max_id: max_id}))
    end
  end

  def outbox(conn, %{"nickname" => nickname}) do
    outbox(conn, %{"nickname" => nickname, "max_id" => nil})
  end

  def inbox(%{assigns: %{valid_signature: true}} = conn, %{"nickname" => nickname} = params) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         true <- Utils.recipient_in_message(user.ap_id, params),
         params <- Utils.maybe_splice_recipient(user.ap_id, params) do
      Federator.enqueue(:incoming_ap_doc, params)
      json(conn, "ok")
    end
  end

  def inbox(%{assigns: %{valid_signature: true}} = conn, params) do
    Federator.enqueue(:incoming_ap_doc, params)
    json(conn, "ok")
  end

  # only accept relayed Creates
  def inbox(conn, %{"type" => "Create"} = params) do
    Logger.info(
      "Signature missing or not from author, relayed Create message, fetching object from source"
    )

    ActivityPub.fetch_object_from_id(params["object"]["id"])

    json(conn, "ok")
  end

  def inbox(conn, params) do
    headers = Enum.into(conn.req_headers, %{})

    if String.contains?(headers["signature"], params["actor"]) do
      Logger.info(
        "Signature validation error for: #{params["actor"]}, make sure you are forwarding the HTTP Host header!"
      )

      Logger.info(inspect(conn.req_headers))
    end

    json(conn, "error")
  end

  def relay(conn, params) do
    with %User{} = user <- Relay.get_actor(),
         {:ok, user} <- Pleroma.Web.WebFinger.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("user.json", %{user: user}))
    else
      nil -> {:error, :not_found}
    end
  end

  def errors(conn, {:error, :not_found}) do
    conn
    |> put_status(404)
    |> json("Not found")
  end

  def errors(conn, _e) do
    conn
    |> put_status(500)
    |> json("error")
  end
end
