# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Federator

  require Logger

  action_fallback(:errors)

  plug(Pleroma.Web.FederatingPlug when action in [:inbox, :relay])
  plug(:set_requester_reachable when action in [:inbox])
  plug(:relay_active? when action in [:relay])

  def relay_active?(conn, _) do
    if Pleroma.Config.get([:instance, :allow_relay]) do
      conn
    else
      conn
      |> put_status(404)
      |> json(%{error: "not found"})
      |> halt
    end
  end

  def user(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
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
         {_, true} <- {:public?, Visibility.is_public?(object)} do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(ObjectView.render("object.json", %{object: object}))
    else
      {:public?, false} ->
        {:error, :not_found}
    end
  end

  def object_likes(conn, %{"uuid" => uuid, "page" => page}) do
    with ap_id <- o_status_url(conn, :object, uuid),
         %Object{} = object <- Object.get_cached_by_ap_id(ap_id),
         {_, true} <- {:public?, Visibility.is_public?(object)},
         likes <- Utils.get_object_likes(object) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(ObjectView.render("likes.json", ap_id, likes, page))
    else
      {:public?, false} ->
        {:error, :not_found}
    end
  end

  def object_likes(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :object, uuid),
         %Object{} = object <- Object.get_cached_by_ap_id(ap_id),
         {_, true} <- {:public?, Visibility.is_public?(object)},
         likes <- Utils.get_object_likes(object) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(ObjectView.render("likes.json", ap_id, likes))
    else
      {:public?, false} ->
        {:error, :not_found}
    end
  end

  def activity(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :activity, uuid),
         %Activity{} = activity <- Activity.normalize(ap_id),
         {_, true} <- {:public?, Visibility.is_public?(activity)} do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(ObjectView.render("object.json", %{object: activity}))
    else
      {:public?, false} ->
        {:error, :not_found}
    end
  end

  def following(conn, %{"nickname" => nickname, "page" => page}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("following.json", %{user: user, page: page}))
    end
  end

  def following(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("following.json", %{user: user}))
    end
  end

  def followers(conn, %{"nickname" => nickname, "page" => page}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("followers.json", %{user: user, page: page}))
    end
  end

  def followers(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("followers.json", %{user: user}))
    end
  end

  def outbox(conn, %{"nickname" => nickname} = params) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("outbox.json", %{user: user, max_id: params["max_id"]}))
    end
  end

  def inbox(%{assigns: %{valid_signature: true}} = conn, %{"nickname" => nickname} = params) do
    with %User{} = recipient <- User.get_cached_by_nickname(nickname),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(params["actor"]),
         true <- Utils.recipient_in_message(recipient, actor, params),
         params <- Utils.maybe_splice_recipient(recipient.ap_id, params) do
      Federator.incoming_ap_doc(params)
      json(conn, "ok")
    end
  end

  def inbox(%{assigns: %{valid_signature: true}} = conn, params) do
    Federator.incoming_ap_doc(params)
    json(conn, "ok")
  end

  # only accept relayed Creates
  def inbox(conn, %{"type" => "Create"} = params) do
    Logger.info(
      "Signature missing or not from author, relayed Create message, fetching object from source"
    )

    Fetcher.fetch_object_from_id(params["object"]["id"])

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

  def relay(conn, _params) do
    with %User{} = user <- Relay.get_actor(),
         {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("user.json", %{user: user}))
    else
      nil -> {:error, :not_found}
    end
  end

  def whoami(%{assigns: %{user: %User{} = user}} = conn, _params) do
    conn
    |> put_resp_header("content-type", "application/activity+json")
    |> json(UserView.render("user.json", %{user: user}))
  end

  def whoami(_conn, _params), do: {:error, :not_found}

  def read_inbox(%{assigns: %{user: user}} = conn, %{"nickname" => nickname} = params) do
    if nickname == user.nickname do
      conn
      |> put_resp_header("content-type", "application/activity+json")
      |> json(UserView.render("inbox.json", %{user: user, max_id: params["max_id"]}))
    else
      conn
      |> put_status(:forbidden)
      |> json("can't read inbox of #{nickname} as #{user.nickname}")
    end
  end

  def handle_user_activity(user, %{"type" => "Create"} = params) do
    object =
      params["object"]
      |> Map.merge(Map.take(params, ["to", "cc"]))
      |> Map.put("attributedTo", user.ap_id())
      |> Transmogrifier.fix_object()

    ActivityPub.create(%{
      to: params["to"],
      actor: user,
      context: object["context"],
      object: object,
      additional: Map.take(params, ["cc"])
    })
  end

  def handle_user_activity(user, %{"type" => "Delete"} = params) do
    with %Object{} = object <- Object.normalize(params["object"]),
         true <- user.info.is_moderator || user.ap_id == object.data["actor"],
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    else
      _ -> {:error, "Can't delete object"}
    end
  end

  def handle_user_activity(user, %{"type" => "Like"} = params) do
    with %Object{} = object <- Object.normalize(params["object"]),
         {:ok, activity, _object} <- ActivityPub.like(user, object) do
      {:ok, activity}
    else
      _ -> {:error, "Can't like object"}
    end
  end

  def handle_user_activity(_, _) do
    {:error, "Unhandled activity type"}
  end

  def update_outbox(
        %{assigns: %{user: user}} = conn,
        %{"nickname" => nickname} = params
      ) do
    if nickname == user.nickname do
      actor = user.ap_id()

      params =
        params
        |> Map.drop(["id"])
        |> Map.put("actor", actor)
        |> Transmogrifier.fix_addressing()

      with {:ok, %Activity{} = activity} <- handle_user_activity(user, params) do
        conn
        |> put_status(:created)
        |> put_resp_header("location", activity.data["id"])
        |> json(activity.data)
      else
        {:error, message} ->
          conn
          |> put_status(:bad_request)
          |> json(message)
      end
    else
      conn
      |> put_status(:forbidden)
      |> json("can't update outbox of #{nickname} as #{user.nickname}")
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

  defp set_requester_reachable(%Plug.Conn{} = conn, _) do
    with actor <- conn.params["actor"],
         true <- is_binary(actor) do
      Pleroma.Instances.set_reachable(actor)
    end

    conn
  end
end
