# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.ModerationLog
  alias Pleroma.Pagination
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:chats"]} when action in [:show, :messages]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:chats"]} when action in [:delete_message]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.ChatOperation

  def delete_message(%{assigns: %{user: user}} = conn, %{
        message_id: message_id,
        id: chat_id
      }) do
    with %MessageReference{object: %{data: %{"id" => object_ap_id}}} = cm_ref <-
           MessageReference.get_by_id(message_id),
         ^chat_id <- to_string(cm_ref.chat_id),
         %Activity{id: activity_id} <- Activity.get_create_by_object_ap_id(object_ap_id),
         {:ok, _} <- CommonAPI.delete(activity_id, user) do
      ModerationLog.insert_log(%{
        action: "chat_message_delete",
        actor: user,
        subject_id: message_id
      })

      conn
      |> put_view(MessageReferenceView)
      |> render("show.json", chat_message_reference: cm_ref)
    else
      _e ->
        {:error, :could_not_delete}
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

  def show(conn, %{id: id}) do
    with %Chat{} = chat <- Chat.get_by_id(id) do
      conn
      |> put_view(AdminAPI.ChatView)
      |> render("show.json", chat: chat)
    end
  end
end
