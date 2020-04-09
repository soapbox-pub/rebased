# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatController do
  use Pleroma.Web, :controller

  alias Pleroma.Chat
  alias Pleroma.Object
  alias Pleroma.Repo

  import Ecto.Query

  def messages(%{assigns: %{user: %{id: user_id} = user}} = conn, %{"id" => id}) do
    with %Chat{} = chat <- Repo.get_by(Chat, id: id, user_id: user_id) do
      messages =
        from(o in Object,
          where: fragment("?->>'type' = ?", o.data, "ChatMessage"),
          where:
            fragment(
              """
              (?->>'actor' = ? and ?->'to' = ?) 
              OR (?->>'actor' = ? and ?->'to' = ?) 
              """,
              o.data,
              ^user.ap_id,
              o.data,
              ^[chat.recipient],
              o.data,
              ^chat.recipient,
              o.data,
              ^[user.ap_id]
            ),
          order_by: [desc: o.id]
        )
        |> Repo.all()

      represented_messages =
        messages
        |> Enum.map(fn message ->
          %{
            actor: message.data["actor"],
            id: message.id,
            content: message.data["content"]
          }
        end)

      conn
      |> json(represented_messages)
    end
  end

  def index(%{assigns: %{user: %{id: user_id}}} = conn, _params) do
    chats =
      from(c in Chat,
        where: c.user_id == ^user_id,
        order_by: [desc: c.updated_at]
      )
      |> Repo.all()

    represented_chats =
      Enum.map(chats, fn chat ->
        %{
          id: chat.id,
          recipient: chat.recipient,
          unread: chat.unread
        }
      end)

    conn
    |> json(represented_chats)
  end

  def create(%{assigns: %{user: user}} = conn, params) do
    recipient = params["ap_id"] |> URI.decode_www_form()

    with {:ok, %Chat{} = chat} <- Chat.get_or_create(user.id, recipient) do
      represented_chat = %{
        id: chat.id,
        recipient: chat.recipient,
        unread: chat.unread
      }

      conn
      |> json(represented_chat)
    end
  end
end
