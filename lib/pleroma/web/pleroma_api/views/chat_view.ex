# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatView do
  use Pleroma.Web, :view

  alias Pleroma.Chat

  def render("show.json", %{chat: %Chat{} = chat}) do
    %{
      id: chat.id |> to_string(),
      recipient: chat.recipient,
      unread: chat.unread
    }
  end

  def render("index.json", %{chats: chats}) do
    render_many(chats, __MODULE__, "show.json")
  end
end
