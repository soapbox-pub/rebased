# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.BookmarkFolderController do
  use Pleroma.Web, :controller

  alias Pleroma.BookmarkFolder
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  # Note: scope not present in Mastodon: read:bookmarks
  plug(OAuthScopesPlug, %{scopes: ["read:bookmarks"]} when action == :index)

  # Note: scope not present in Mastodon: write:bookmarks
  plug(
    OAuthScopesPlug,
    %{scopes: ["write:bookmarks"]} when action in [:create, :update, :delete]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaBookmarkFolderOperation

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  def index(%{assigns: %{user: user}} = conn, _params) do
    with folders <- BookmarkFolder.for_user(user.id) do
      conn
      |> render("index.json", %{folders: folders, as: :folder})
    end
  end

  def create(
        %{assigns: %{user: user}, private: %{open_api_spex: %{body_params: params}}} = conn,
        _
      ) do
    with {:ok, folder} <- BookmarkFolder.create(user.id, params[:name], params[:emoji]) do
      render(conn, "show.json", folder: folder)
    end
  end

  def update(
        %{
          assigns: %{user: user},
          private: %{open_api_spex: %{body_params: params, params: %{id: id}}}
        } = conn,
        _
      ) do
    with true <- BookmarkFolder.belongs_to_user?(id, user.id),
         {:ok, folder} <- BookmarkFolder.update(id, params[:name], params[:emoji]) do
      render(conn, "show.json", folder: folder)
    else
      false -> {:error, :forbidden}
    end
  end

  def delete(
        %{assigns: %{user: user}, private: %{open_api_spex: %{params: %{id: id}}}} = conn,
        _
      ) do
    with true <- BookmarkFolder.belongs_to_user?(id, user.id),
         {:ok, folder} <- BookmarkFolder.delete(id) do
      render(conn, "show.json", folder: folder)
    else
      false -> {:error, :forbidden}
    end
  end
end
