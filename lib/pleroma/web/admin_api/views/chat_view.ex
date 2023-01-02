# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatView do
  use Pleroma.Web, :view

  alias Pleroma.Chat
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI
  alias Pleroma.Web.PleromaAPI

  def render("index.json", %{chats: chats} = opts) do
    render_many(chats, __MODULE__, "show.json", Map.delete(opts, :chats))
  end

  def render("show.json", %{chat: %Chat{user_id: user_id}} = opts) do
    user = User.get_by_id(user_id)
    sender = MastodonAPI.AccountView.render("show.json", user: user, skip_visibility_check: true)

    serialized_chat = PleromaAPI.ChatView.render("show.json", opts)

    serialized_chat
    |> Map.put(:sender, sender)
    |> Map.put(:receiver, serialized_chat[:account])
    |> Map.delete(:account)
  end

  def render(view, opts), do: PleromaAPI.ChatView.render(view, opts)
end
