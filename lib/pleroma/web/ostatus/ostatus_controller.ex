# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.OStatusController do
  use Pleroma.Web, :controller

  alias Fallback.RedirectController
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.ActivityPubController
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Federator
  alias Pleroma.Web.Metadata.PlayerView
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.OStatus.ActivityRepresenter
  alias Pleroma.Web.OStatus.FeedRepresenter
  alias Pleroma.Web.Router
  alias Pleroma.Web.XML

  plug(
    Pleroma.Plugs.RateLimiter,
    {:ap_routes, params: ["uuid"]} when action in [:object, :activity]
  )

  plug(Pleroma.Web.FederatingPlug when action in [:salmon_incoming])

  plug(
    Pleroma.Plugs.SetFormatPlug
    when action in [:feed_redirect, :object, :activity, :notice]
  )

  action_fallback(:errors)

  def feed_redirect(%{assigns: %{format: "html"}} = conn, %{"nickname" => nickname}) do
    with {_, %User{} = user} <- {:fetch_user, User.get_cached_by_nickname_or_id(nickname)} do
      RedirectController.redirector_with_meta(conn, %{user: user})
    end
  end

  def feed_redirect(%{assigns: %{format: format}} = conn, _params)
      when format in ["json", "activity+json"] do
    ActivityPubController.call(conn, :user)
  end

  def feed_redirect(conn, %{"nickname" => nickname}) do
    with {_, %User{} = user} <- {:fetch_user, User.get_cached_by_nickname(nickname)} do
      redirect(conn, external: OStatus.feed_path(user))
    end
  end

  def feed(conn, %{"nickname" => nickname} = params) do
    with {_, %User{} = user} <- {:fetch_user, User.get_cached_by_nickname(nickname)} do
      activities =
        params
        |> Map.take(["max_id"])
        |> Map.merge(%{"whole_db" => true, "actor_id" => user.ap_id})
        |> ActivityPub.fetch_public_activities()
        |> Enum.reverse()

      response =
        user
        |> FeedRepresenter.to_simple_form(activities, [user])
        |> :xmerl.export_simple(:xmerl_xml)
        |> to_string

      conn
      |> put_resp_content_type("application/atom+xml")
      |> send_resp(200, response)
    end
  end

  defp decode_or_retry(body) do
    with {:ok, magic_key} <- Pleroma.Web.Salmon.fetch_magic_key(body),
         {:ok, doc} <- Pleroma.Web.Salmon.decode_and_validate(magic_key, body) do
      {:ok, doc}
    else
      _e ->
        with [decoded | _] <- Pleroma.Web.Salmon.decode(body),
             doc <- XML.parse_document(decoded),
             uri when not is_nil(uri) <- XML.string_from_xpath("/entry/author[1]/uri", doc),
             {:ok, _} <- Pleroma.Web.OStatus.make_user(uri, true),
             {:ok, magic_key} <- Pleroma.Web.Salmon.fetch_magic_key(body),
             {:ok, doc} <- Pleroma.Web.Salmon.decode_and_validate(magic_key, body) do
          {:ok, doc}
        end
    end
  end

  def salmon_incoming(conn, _) do
    {:ok, body, _conn} = read_body(conn)
    {:ok, doc} = decode_or_retry(body)

    Federator.incoming_doc(doc)

    send_resp(conn, 200, "")
  end

  def object(%{assigns: %{format: format}} = conn, %{"uuid" => _uuid})
      when format in ["json", "activity+json"] do
    ActivityPubController.call(conn, :object)
  end

  def object(%{assigns: %{format: format}} = conn, %{"uuid" => uuid}) do
    with id <- o_status_url(conn, :object, uuid),
         {_, %Activity{} = activity} <-
           {:activity, Activity.get_create_by_object_ap_id_with_object(id)},
         {_, true} <- {:public?, Visibility.is_public?(activity)},
         %User{} = user <- User.get_cached_by_ap_id(activity.data["actor"]) do
      case format do
        "html" -> redirect(conn, to: "/notice/#{activity.id}")
        _ -> represent_activity(conn, nil, activity, user)
      end
    else
      reason when reason in [{:public?, false}, {:activity, nil}] ->
        {:error, :not_found}

      e ->
        e
    end
  end

  def activity(%{assigns: %{format: format}} = conn, %{"uuid" => _uuid})
      when format in ["json", "activity+json"] do
    ActivityPubController.call(conn, :activity)
  end

  def activity(%{assigns: %{format: format}} = conn, %{"uuid" => uuid}) do
    with id <- o_status_url(conn, :activity, uuid),
         {_, %Activity{} = activity} <- {:activity, Activity.normalize(id)},
         {_, true} <- {:public?, Visibility.is_public?(activity)},
         %User{} = user <- User.get_cached_by_ap_id(activity.data["actor"]) do
      case format do
        "html" -> redirect(conn, to: "/notice/#{activity.id}")
        _ -> represent_activity(conn, format, activity, user)
      end
    else
      reason when reason in [{:public?, false}, {:activity, nil}] ->
        {:error, :not_found}

      e ->
        e
    end
  end

  def notice(%{assigns: %{format: format}} = conn, %{"id" => id}) do
    with {_, %Activity{} = activity} <- {:activity, Activity.get_by_id_with_object(id)},
         {_, true} <- {:public?, Visibility.is_public?(activity)},
         %User{} = user <- User.get_cached_by_ap_id(activity.data["actor"]) do
      cond do
        format == "html" && activity.data["type"] == "Create" ->
          %Object{} = object = Object.normalize(activity)

          RedirectController.redirector_with_meta(
            conn,
            %{
              activity_id: activity.id,
              object: object,
              url: Router.Helpers.o_status_url(Endpoint, :notice, activity.id),
              user: user
            }
          )

        format == "html" ->
          RedirectController.redirector(conn, nil)

        true ->
          represent_activity(conn, format, activity, user)
      end
    else
      reason when reason in [{:public?, false}, {:activity, nil}] ->
        conn
        |> put_status(404)
        |> RedirectController.redirector(nil, 404)

      e ->
        e
    end
  end

  # Returns an HTML embedded <audio> or <video> player suitable for embed iframes.
  def notice_player(conn, %{"id" => id}) do
    with %Activity{data: %{"type" => "Create"}} = activity <- Activity.get_by_id_with_object(id),
         true <- Visibility.is_public?(activity),
         %Object{} = object <- Object.normalize(activity),
         %{data: %{"attachment" => [%{"url" => [url | _]} | _]}} <- object,
         true <- String.starts_with?(url["mediaType"], ["audio", "video"]) do
      conn
      |> put_layout(:metadata_player)
      |> put_resp_header("x-frame-options", "ALLOW")
      |> put_resp_header(
        "content-security-policy",
        "default-src 'none';style-src 'self' 'unsafe-inline';img-src 'self' data: https:; media-src 'self' https:;"
      )
      |> put_view(PlayerView)
      |> render("player.html", url)
    else
      _error ->
        conn
        |> put_status(404)
        |> RedirectController.redirector(nil, 404)
    end
  end

  defp represent_activity(
         conn,
         "activity+json",
         %Activity{data: %{"type" => "Create"}} = activity,
         _user
       ) do
    object = Object.normalize(activity)

    conn
    |> put_resp_header("content-type", "application/activity+json")
    |> json(ObjectView.render("object.json", %{object: object}))
  end

  defp represent_activity(_conn, "activity+json", _, _) do
    {:error, :not_found}
  end

  defp represent_activity(conn, _, activity, user) do
    response =
      activity
      |> ActivityRepresenter.to_simple_form(user, true)
      |> ActivityRepresenter.wrap_with_entry()
      |> :xmerl.export_simple(:xmerl_xml)
      |> to_string

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def errors(conn, {:error, :not_found}) do
    render_error(conn, :not_found, "Not found")
  end

  def errors(conn, {:fetch_user, nil}), do: errors(conn, {:error, :not_found})

  def errors(conn, _) do
    render_error(conn, :internal_server_error, "Something went wrong")
  end
end
