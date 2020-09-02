# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.ModerationLog
  alias Pleroma.Pagination
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:chats"], admin: true} when action in [:messages]
  )

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

  def messages(conn, %{id: id} = params) do
    with %Chat{} = chat <- Chat.get_by_id(id) do
      cm_refs =
        chat
        |> MessageReference.for_chat_query()
        |> Pagination.fetch_paginated(params)

      conn
      |> put_view(MessageReferenceView)
      |> render("index.json", chat_message_references: cm_refs)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not found"})
    end
  end
end
