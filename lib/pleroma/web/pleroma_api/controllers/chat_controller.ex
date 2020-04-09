# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatController do
  use Pleroma.Web, :controller

  alias Pleroma.Chat
  alias Pleroma.Repo

  import Ecto.Query

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
