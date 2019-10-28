# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.OStatusController do
  use Pleroma.Web, :controller

  alias Fallback.RedirectController
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPubController
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Metadata.PlayerView
  alias Pleroma.Web.Router

  plug(
    Pleroma.Plugs.RateLimiter,
    {:ap_routes, params: ["uuid"]} when action in [:object, :activity]
  )

  plug(
    Pleroma.Plugs.SetFormatPlug
    when action in [:object, :activity, :notice]
  )

  action_fallback(:errors)

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
    if Pleroma.Config.get([:instance, :static_fe], false) do
      Pleroma.Web.StaticFE.StaticFEController.show(conn, %{"notice_id" => id})
    else
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
    |> put_view(ObjectView)
    |> render("object.json", %{object: object})
  end

  defp represent_activity(_conn, _, _, _) do
    {:error, :not_found}
  end

  def errors(conn, {:error, :not_found}) do
    render_error(conn, :not_found, "Not found")
  end

  def errors(conn, {:fetch_user, nil}), do: errors(conn, {:error, :not_found})

  def errors(conn, _) do
    render_error(conn, :internal_server_error, "Something went wrong")
  end
end
