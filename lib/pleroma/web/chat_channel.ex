# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ChatChannel do
  use Phoenix.Channel
  alias Pleroma.User
  alias Pleroma.Web.ChatChannel.ChatChannelState

  def join("chat:public", _message, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    push(socket, "messages", %{messages: ChatChannelState.messages()})
    {:noreply, socket}
  end

  def handle_in("new_msg", %{"text" => text}, %{assigns: %{user_name: user_name}} = socket) do
    text = String.trim(text)

    if String.length(text) > 0 do
      author = User.get_cached_by_nickname(user_name)
      author = Pleroma.Web.MastodonAPI.AccountView.render("show.json", user: author)
      message = ChatChannelState.add_message(%{text: text, author: author})

      broadcast!(socket, "new_msg", message)
    end

    {:noreply, socket}
  end
end

defmodule Pleroma.Web.ChatChannel.ChatChannelState do
  use Agent

  @max_messages 20

  def start_link(_) do
    Agent.start_link(fn -> %{max_id: 1, messages: []} end, name: __MODULE__)
  end

  def add_message(message) do
    Agent.get_and_update(__MODULE__, fn state ->
      id = state[:max_id] + 1
      message = Map.put(message, "id", id)
      messages = [message | state[:messages]] |> Enum.take(@max_messages)
      {message, %{max_id: id, messages: messages}}
    end)
  end

  def messages do
    Agent.get(__MODULE__, fn state -> state[:messages] |> Enum.reverse() end)
  end
end
