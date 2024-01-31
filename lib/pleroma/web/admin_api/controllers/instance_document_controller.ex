# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InstanceDocumentController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.InstanceDocument
  alias Pleroma.Web.Plugs.InstanceStatic
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.InstanceDocumentOperation

  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action == :show)
  plug(OAuthScopesPlug, %{scopes: ["admin:write"]} when action in [:update, :delete])

  def show(%{private: %{open_api_spex: %{params: %{name: document_name}}}} = conn, _) do
    with {:ok, url} <- InstanceDocument.get(document_name),
         {:ok, content} <- File.read(InstanceStatic.file_path(url)) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, content)
    end
  end

  def update(
        %{
          private: %{open_api_spex: %{body_params: %{file: file}, params: %{name: document_name}}}
        } = conn,
        _
      ) do
    with {:ok, url} <- InstanceDocument.put(document_name, file.path) do
      json(conn, %{"url" => url})
    end
  end

  def delete(%{private: %{open_api_spex: %{params: %{name: document_name}}}} = conn, _) do
    with :ok <- InstanceDocument.delete(document_name) do
      json(conn, %{})
    end
  end
end
