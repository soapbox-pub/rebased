# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaController do
  use Pleroma.Web, :controller

  alias Pleroma.Object
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)
  plug(:put_view, Pleroma.Web.MastodonAPI.StatusView)

  plug(OAuthScopesPlug, %{scopes: ["write:media"]})

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @doc "POST /api/v1/media"
  def create(%{assigns: %{user: user}} = conn, %{"file" => file} = data) do
    with {:ok, object} <-
           ActivityPub.upload(
             file,
             actor: User.ap_id(user),
             description: Map.get(data, "description")
           ) do
      attachment_data = Map.put(object.data, "id", object.id)

      render(conn, "attachment.json", %{attachment: attachment_data})
    end
  end

  @doc "PUT /api/v1/media/:id"
  def update(%{assigns: %{user: user}} = conn, %{"id" => id, "description" => description})
      when is_binary(description) do
    with %Object{} = object <- Object.get_by_id(id),
         true <- Object.authorize_mutation(object, user),
         {:ok, %Object{data: data}} <- Object.update_data(object, %{"name" => description}) do
      attachment_data = Map.put(data, "id", object.id)

      render(conn, "attachment.json", %{attachment: attachment_data})
    end
  end

  def update(_conn, _data), do: {:error, :bad_request}
end
