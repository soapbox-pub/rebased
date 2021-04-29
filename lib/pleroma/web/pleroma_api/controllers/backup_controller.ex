# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.BackupController do
  use Pleroma.Web, :controller

  alias Pleroma.User.Backup
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)
  plug(OAuthScopesPlug, %{scopes: ["read:accounts"]} when action in [:index, :create])
  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaBackupOperation

  def index(%{assigns: %{user: user}} = conn, _params) do
    backups = Backup.list(user)
    render(conn, "index.json", backups: backups)
  end

  def create(%{assigns: %{user: user}} = conn, _params) do
    with {:ok, _} <- Backup.create(user) do
      backups = Backup.list(user)
      render(conn, "index.json", backups: backups)
    end
  end
end
