# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InstanceDocumentController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.InstanceStatic
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.InstanceDocument

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.InstanceDocumentOperation

  plug(OAuthScopesPlug, %{scopes: ["read"], admin: true} when action == :show)
  plug(OAuthScopesPlug, %{scopes: ["write"], admin: true} when action in [:update, :delete])

  def show(conn, %{name: document_name}) do
    with {:ok, url} <- InstanceDocument.get(document_name),
         {:ok, content} <- File.read(InstanceStatic.file_path(url)) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, content)
    end
  end

  def update(%{body_params: %{file: file}} = conn, %{name: document_name}) do
    with {:ok, url} <- InstanceDocument.put(document_name, file.path) do
      json(conn, %{"url" => url})
    end
  end

  def delete(conn, %{name: document_name}) do
    with :ok <- InstanceDocument.delete(document_name) do
      json(conn, %{})
    end
  end
end
