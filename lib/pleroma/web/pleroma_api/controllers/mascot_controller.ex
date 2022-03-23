# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.MascotController do
  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Majic.Plug, [pool: Pleroma.MajicPool] when action in [:update])
  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["read:accounts"]} when action == :show)
  plug(OAuthScopesPlug, %{scopes: ["write:accounts"]} when action != :show)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaMascotOperation

  @doc "GET /api/v1/pleroma/mascot"
  def show(%{assigns: %{user: user}} = conn, _params) do
    json(conn, User.get_mascot(user))
  end

  @doc "PUT /api/v1/pleroma/mascot"
  def update(%{assigns: %{user: user}, body_params: %{file: file}} = conn, _) do
    with {:content_type, "image" <> _} <- {:content_type, file.content_type},
         {:ok, object} <- ActivityPub.upload(file, actor: User.ap_id(user)) do
      attachment = render_attachment(object)
      {:ok, _user} = User.mascot_update(user, attachment)

      json(conn, attachment)
    else
      {:content_type, _} ->
        render_error(conn, :unsupported_media_type, "mascots can only be images")
    end
  end

  defp render_attachment(object) do
    attachment_data = Map.put(object.data, "id", object.id)
    Pleroma.Web.MastodonAPI.StatusView.render("attachment.json", %{attachment: attachment_data})
  end
end
