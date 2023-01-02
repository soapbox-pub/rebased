# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AnnouncementController do
  use Pleroma.Web, :controller

  alias Pleroma.Announcement
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["admin:write"]} when action in [:create, :delete, :change])
  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action in [:index, :show])
  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.AnnouncementOperation

  defp default_limit, do: 20

  def index(conn, params) do
    limit = Map.get(params, :limit, default_limit())
    offset = Map.get(params, :offset, 0)

    announcements = Announcement.list_paginated(%{limit: limit, offset: offset})

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
    with {:ok, announcement} <- Announcement.add(change_params(params)) do
      render(conn, "show.json", announcement: announcement)
    else
      _ ->
        {:error, 400}
    end
  end

  def change_params(orig_params) do
    data =
      %{}
      |> Pleroma.Maps.put_if_present("content", orig_params, &Map.fetch(&1, :content))
      |> Pleroma.Maps.put_if_present("all_day", orig_params, &Map.fetch(&1, :all_day))

    orig_params
    |> Map.merge(%{data: data})
  end

  def change(%{body_params: params} = conn, %{id: id} = _params) do
    with announcement <- Announcement.get_by_id(id),
         {:exists, true} <- {:exists, not is_nil(announcement)},
         {:ok, announcement} <- Announcement.update(announcement, change_params(params)) do
      render(conn, "show.json", announcement: announcement)
    else
      {:exists, false} ->
        {:error, :not_found}

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
