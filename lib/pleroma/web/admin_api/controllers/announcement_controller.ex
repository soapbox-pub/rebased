# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AnnouncementController do
  use Pleroma.Web, :controller

  alias Pleroma.Announcement
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["admin:write"]} when action in [:create, :delete])
  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action in [:index, :show])
  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.AnnouncementOperation

  def index(conn, _params) do
    announcements = Announcement.list_all()

    render(conn, "index.json", announcements: announcements)
  end

  def show(conn, %{id: id} = _params) do
    announcement = Announcement.get_by_id(id)

    if is_nil(announcement) do
      {:error, :not_found}
    else
      render(conn, "show.json", announcement: announcement)
    end
  end

  def create(%{body_params: params} = conn, _params) do
    data =
      %{}
      |> Pleroma.Maps.put_if_present("content", params, &Map.fetch(&1, :content))
      |> Pleroma.Maps.put_if_present("all_day", params, &Map.fetch(&1, :all_day))

    add_params =
      params
      |> Map.merge(%{data: data})

    with {:ok, announcement} <- Announcement.add(add_params) do
      render(conn, "show.json", announcement: announcement)
    else
      _ ->
        {:error, 400}
    end
  end

  def delete(conn, %{id: id} = _params) do
    case Announcement.delete_by_id(id) do
      :ok ->
        conn
        |> ControllerHelper.json_response(:ok, %{})

      _ ->
        {:error, :not_found}
    end
  end
end
