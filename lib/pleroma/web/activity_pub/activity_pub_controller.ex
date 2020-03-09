# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Delivery
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.Plugs.EnsureAuthenticatedPlug
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.InternalFetchActor
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.FederatingPlug
  alias Pleroma.Web.Federator

  require Logger

  action_fallback(:errors)

  @federating_only_actions [:internal_fetch, :relay, :relay_following, :relay_followers]

  plug(FederatingPlug when action in @federating_only_actions)

  plug(
    EnsureAuthenticatedPlug,
    [unless_func: &FederatingPlug.federating?/0] when action not in @federating_only_actions
  )

  plug(
    EnsureAuthenticatedPlug
    when action in [:read_inbox, :update_outbox, :whoami, :upload_media, :following, :followers]
  )

  plug(
    Pleroma.Plugs.Cache,
    [query_params: false, tracking_fun: &__MODULE__.track_object_fetch/2]
    when action in [:activity, :object]
  )

  plug(:set_requester_reachable when action in [:inbox])
  plug(:relay_active? when action in [:relay])

  defp relay_active?(conn, _) do
    if Pleroma.Config.get([:instance, :allow_relay]) do
      conn
    else
      conn
      |> render_error(:not_found, "not found")
      |> halt()
    end
  end

  def user(conn, %{"nickname" => nickname}) do
    with %User{local: true} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("user.json", %{user: user})
    else
      nil -> {:error, :not_found}
      %{local: false} -> {:error, :not_found}
    end
  end

  def object(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :object, uuid),
         %Object{} = object <- Object.get_cached_by_ap_id(ap_id),
         {_, true} <- {:public?, Visibility.is_public?(object)} do
      conn
      |> assign(:tracking_fun_data, object.id)
      |> set_cache_ttl_for(object)
      |> put_resp_content_type("application/activity+json")
      |> put_view(ObjectView)
      |> render("object.json", object: object)
    else
      {:public?, false} ->
        {:error, :not_found}
    end
  end

  def track_object_fetch(conn, nil), do: conn

  def track_object_fetch(conn, object_id) do
    with %{assigns: %{user: %User{id: user_id}}} <- conn do
      Delivery.create(object_id, user_id)
    end

    conn
  end

  def activity(conn, %{"uuid" => uuid}) do
    with ap_id <- o_status_url(conn, :activity, uuid),
         %Activity{} = activity <- Activity.normalize(ap_id),
         {_, true} <- {:public?, Visibility.is_public?(activity)} do
      conn
      |> maybe_set_tracking_data(activity)
      |> set_cache_ttl_for(activity)
      |> put_resp_content_type("application/activity+json")
      |> put_view(ObjectView)
      |> render("object.json", object: activity)
    else
      {:public?, false} -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  defp maybe_set_tracking_data(conn, %Activity{data: %{"type" => "Create"}} = activity) do
    object_id = Object.normalize(activity).id
    assign(conn, :tracking_fun_data, object_id)
  end

  defp maybe_set_tracking_data(conn, _activity), do: conn

  defp set_cache_ttl_for(conn, %Activity{object: object}) do
    set_cache_ttl_for(conn, object)
  end

  defp set_cache_ttl_for(conn, entity) do
    ttl =
      case entity do
        %Object{data: %{"type" => "Question"}} ->
          Pleroma.Config.get([:web_cache_ttl, :activity_pub_question])

        %Object{} ->
          Pleroma.Config.get([:web_cache_ttl, :activity_pub])

        _ ->
          nil
      end

    assign(conn, :cache_ttl, ttl)
  end

  # GET /relay/following
  def relay_following(conn, _params) do
    with %{halted: false} = conn <- FederatingPlug.call(conn, []) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("following.json", %{user: Relay.get_actor()})
    end
  end

  def following(%{assigns: %{user: for_user}} = conn, %{"nickname" => nickname, "page" => page}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {user, for_user} <- ensure_user_keys_present_and_maybe_refresh_for_user(user, for_user),
         {:show_follows, true} <-
           {:show_follows, (for_user && for_user == user) || !user.hide_follows} do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("following.json", %{user: user, page: page, for: for_user})
    else
      {:show_follows, _} ->
        conn
        |> put_resp_content_type("application/activity+json")
        |> send_resp(403, "")
    end
  end

  def following(%{assigns: %{user: for_user}} = conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {user, for_user} <- ensure_user_keys_present_and_maybe_refresh_for_user(user, for_user) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("following.json", %{user: user, for: for_user})
    end
  end

  # GET /relay/followers
  def relay_followers(conn, _params) do
    with %{halted: false} = conn <- FederatingPlug.call(conn, []) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("followers.json", %{user: Relay.get_actor()})
    end
  end

  def followers(%{assigns: %{user: for_user}} = conn, %{"nickname" => nickname, "page" => page}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {user, for_user} <- ensure_user_keys_present_and_maybe_refresh_for_user(user, for_user),
         {:show_followers, true} <-
           {:show_followers, (for_user && for_user == user) || !user.hide_followers} do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("followers.json", %{user: user, page: page, for: for_user})
    else
      {:show_followers, _} ->
        conn
        |> put_resp_content_type("application/activity+json")
        |> send_resp(403, "")
    end
  end

  def followers(%{assigns: %{user: for_user}} = conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {user, for_user} <- ensure_user_keys_present_and_maybe_refresh_for_user(user, for_user) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("followers.json", %{user: user, for: for_user})
    end
  end

  def outbox(
        %{assigns: %{user: for_user}} = conn,
        %{"nickname" => nickname, "page" => page?} = params
      )
      when page? in [true, "true"] do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      activities =
        if params["max_id"] do
          ActivityPub.fetch_user_activities(user, for_user, %{
            "max_id" => params["max_id"],
            # This is a hack because postgres generates inefficient queries when filtering by
            # 'Answer', poll votes will be hidden by the visibility filter in this case anyway
            "include_poll_votes" => true,
            "limit" => 10
          })
        else
          ActivityPub.fetch_user_activities(user, for_user, %{
            "limit" => 10,
            "include_poll_votes" => true
          })
        end

      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("activity_collection_page.json", %{
        activities: activities,
        iri: "#{user.ap_id}/outbox"
      })
    end
  end

  def outbox(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("activity_collection.json", %{iri: "#{user.ap_id}/outbox"})
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

  # POST /relay/inbox -or- POST /internal/fetch/inbox
  def inbox(conn, params) do
    if params["type"] == "Create" && FederatingPlug.federating?() do
      post_inbox_relayed_create(conn, params)
    else
      post_inbox_fallback(conn, params)
    end
  end

  defp post_inbox_relayed_create(conn, params) do
    Logger.debug(
      "Signature missing or not from author, relayed Create message, fetching object from source"
    )

    Fetcher.fetch_object_from_id(params["object"]["id"])

    json(conn, "ok")
  end

  defp post_inbox_fallback(conn, params) do
    headers = Enum.into(conn.req_headers, %{})

    if headers["signature"] && params["actor"] &&
         String.contains?(headers["signature"], params["actor"]) do
      Logger.debug(
        "Signature validation error for: #{params["actor"]}, make sure you are forwarding the HTTP Host header!"
      )

      Logger.debug(inspect(conn.req_headers))
    end

    conn
    |> put_status(:bad_request)
    |> json(dgettext("errors", "error"))
  end

  defp represent_service_actor(%User{} = user, conn) do
    with {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("user.json", %{user: user})
    else
      nil -> {:error, :not_found}
    end
  end

  defp represent_service_actor(nil, _), do: {:error, :not_found}

  def relay(conn, _params) do
    Relay.get_actor()
    |> represent_service_actor(conn)
  end

  def internal_fetch(conn, _params) do
    InternalFetchActor.get_actor()
    |> represent_service_actor(conn)
  end

  @doc "Returns the authenticated user's ActivityPub User object or a 404 Not Found if non-authenticated"
  def whoami(%{assigns: %{user: %User{} = user}} = conn, _params) do
    conn
    |> put_resp_content_type("application/activity+json")
    |> put_view(UserView)
    |> render("user.json", %{user: user})
  end

  def read_inbox(
        %{assigns: %{user: %User{nickname: nickname} = user}} = conn,
        %{"nickname" => nickname, "page" => page?} = params
      )
      when page? in [true, "true"] do
    activities =
      if params["max_id"] do
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], %{
          "max_id" => params["max_id"],
          "limit" => 10
        })
      else
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], %{"limit" => 10})
      end

    conn
    |> put_resp_content_type("application/activity+json")
    |> put_view(UserView)
    |> render("activity_collection_page.json", %{
      activities: activities,
      iri: "#{user.ap_id}/inbox"
    })
  end

  def read_inbox(%{assigns: %{user: %User{nickname: nickname} = user}} = conn, %{
        "nickname" => nickname
      }) do
    with {:ok, user} <- User.ensure_keys_present(user) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(UserView)
      |> render("activity_collection.json", %{iri: "#{user.ap_id}/inbox"})
    end
  end

  def read_inbox(%{assigns: %{user: %User{nickname: as_nickname}}} = conn, %{
        "nickname" => nickname
      }) do
    err =
      dgettext("errors", "can't read inbox of %{nickname} as %{as_nickname}",
        nickname: nickname,
        as_nickname: as_nickname
      )

    conn
    |> put_status(:forbidden)
    |> json(err)
  end

  defp handle_user_activity(%User{} = user, %{"type" => "Create"} = params) do
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

  defp handle_user_activity(%User{} = user, %{"type" => "Delete"} = params) do
    with %Object{} = object <- Object.normalize(params["object"]),
         true <- user.is_moderator || user.ap_id == object.data["actor"],
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    else
      _ -> {:error, dgettext("errors", "Can't delete object")}
    end
  end

  defp handle_user_activity(%User{} = user, %{"type" => "Like"} = params) do
    with %Object{} = object <- Object.normalize(params["object"]),
         {:ok, activity, _object} <- ActivityPub.like(user, object) do
      {:ok, activity}
    else
      _ -> {:error, dgettext("errors", "Can't like object")}
    end
  end

  defp handle_user_activity(_, _) do
    {:error, dgettext("errors", "Unhandled activity type")}
  end

  def update_outbox(
        %{assigns: %{user: %User{nickname: nickname} = user}} = conn,
        %{"nickname" => nickname} = params
      ) do
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
  end

  def update_outbox(%{assigns: %{user: %User{} = user}} = conn, %{"nickname" => nickname}) do
    err =
      dgettext("errors", "can't update outbox of %{nickname} as %{as_nickname}",
        nickname: nickname,
        as_nickname: user.nickname
      )

    conn
    |> put_status(:forbidden)
    |> json(err)
  end

  defp errors(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(dgettext("errors", "Not found"))
  end

  defp errors(conn, _e) do
    conn
    |> put_status(:internal_server_error)
    |> json(dgettext("errors", "error"))
  end

  defp set_requester_reachable(%Plug.Conn{} = conn, _) do
    with actor <- conn.params["actor"],
         true <- is_binary(actor) do
      Pleroma.Instances.set_reachable(actor)
    end

    conn
  end

  defp ensure_user_keys_present_and_maybe_refresh_for_user(user, for_user) do
    {:ok, new_user} = User.ensure_keys_present(user)

    for_user =
      if new_user != user and match?(%User{}, for_user) do
        User.get_cached_by_nickname(for_user.nickname)
      else
        for_user
      end

    {new_user, for_user}
  end

  # TODO: Add support for "object" field
  @doc """
  Endpoint based on <https://www.w3.org/wiki/SocialCG/ActivityPub/MediaUpload>

  Parameters:
  - (required) `file`: data of the media
  - (optionnal) `description`: description of the media, intended for accessibility

  Response:
  - HTTP Code: 201 Created
  - HTTP Body: ActivityPub object to be inserted into another's `attachment` field
  """
  def upload_media(%{assigns: %{user: %User{} = user}} = conn, %{"file" => file} = data) do
    with {:ok, object} <-
           ActivityPub.upload(
             file,
             actor: User.ap_id(user),
             description: Map.get(data, "description")
           ) do
      Logger.debug(inspect(object))

      conn
      |> put_status(:created)
      |> json(object.data)
    end
  end
end
