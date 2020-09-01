# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.CommonAPI

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:chats"], admin: true} when action in [:delete_message]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.ChatOperation

  def delete_message(%{assigns: %{user: user}} = conn, %{message_id: id}) do
    with {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      ModerationLog.insert_log(%{
        action: "chat_message_delete",
        actor: user,
        subject_id: id
      })

      json(conn, %{})
    end
  end
end
