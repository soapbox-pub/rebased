# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaController do
  use Pleroma.Web, :controller

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)
  plug(Majic.Plug, [pool: Pleroma.MajicPool] when action in [:create, :create2])
  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(OAuthScopesPlug, %{scopes: ["read:media"]} when action == :show)
  plug(OAuthScopesPlug, %{scopes: ["write:media"]} when action != :show)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.MediaOperation

  @doc "POST /api/v1/media"
  def create(%{assigns: %{user: user}, body_params: %{file: file} = data} = conn, _) do
    with {:ok, object} <-
           ActivityPub.upload(
             file,
             actor: User.ap_id(user),
             description: Map.get(data, :description),
             description_map: Map.get(data, :description_map)
           ) do
      attachment_data = Map.put(object.data, "id", object.id)

      render(conn, "attachment.json", %{attachment: attachment_data})
    else
      {:error, e} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: e})
    end
  end

  def create(_conn, _data), do: {:error, :bad_request}

  @doc "POST /api/v2/media"
  def create2(%{assigns: %{user: user}, body_params: %{file: file} = data} = conn, _) do
    with {:ok, object} <-
           ActivityPub.upload(
             file,
             actor: User.ap_id(user),
             description: Map.get(data, :description),
             description_map: Map.get(data, :description_map)
           ) do
      attachment_data = Map.put(object.data, "id", object.id)

      conn
      |> put_status(202)
      |> render("attachment.json", %{attachment: attachment_data})
    else
      {:error, e} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: e})
    end
  end

  def create2(_conn, _data), do: {:error, :bad_request}

  @doc "PUT /api/v1/media/:id"
  def update(
        %{assigns: %{user: user}, body_params: %{description_map: %{} = description_map}} = conn,
        %{id: id}
      ) do
    with %Object{} = object <- Object.get_by_id(id),
         :ok <- Object.authorize_access(object, user),
         {_, {:ok, %{}}} <-
           {:description_map, Pleroma.MultiLanguage.validate_map(description_map)},
         {:ok, %Object{data: data}} <-
           Object.update_data(object, %{
             "name" => Pleroma.MultiLanguage.map_to_str(description_map),
             "nameMap" => description_map
           }) do
      attachment_data = Map.put(data, "id", object.id)

      render(conn, "attachment.json", %{attachment: attachment_data})
    else
      {:description_map, _} -> render_error(conn, 422, "description_map not valid")
    end
  end

  def update(%{assigns: %{user: user}, body_params: %{description: description}} = conn, %{id: id}) do
    with %Object{} = object <- Object.get_by_id(id),
         :ok <- Object.authorize_access(object, user),
         {:ok, %Object{data: data}} <- Object.update_data(object, %{"name" => description}) do
      attachment_data = Map.put(data, "id", object.id)

      render(conn, "attachment.json", %{attachment: attachment_data})
    end
  end

  def update(conn, data), do: show(conn, data)

  @doc "GET /api/v1/media/:id"
  def show(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Object{data: data, id: object_id} = object <- Object.get_by_id(id),
         :ok <- Object.authorize_access(object, user) do
      attachment_data = Map.put(data, "id", object_id)

      render(conn, "attachment.json", %{attachment: attachment_data})
    end
  end

  def show(_conn, _data), do: {:error, :bad_request}
end
