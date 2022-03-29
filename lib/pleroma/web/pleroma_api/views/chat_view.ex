# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatView do
  use Pleroma.Web, :view

  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView

  def render("show.json", %{chat: %Chat{} = chat} = opts) do
    recipient = User.get_cached_by_ap_id(chat.recipient)
    last_message = opts[:last_message] || MessageReference.last_message_for_chat(chat)
    account_view_opts = account_view_opts(opts, recipient)

    %{
      id: chat.id |> to_string(),
      account: AccountView.render("show.json", account_view_opts),
      unread: MessageReference.unread_count_for_chat(chat),
      last_message:
        last_message &&
          MessageReferenceView.render("show.json", chat_message_reference: last_message),
      updated_at: Utils.to_masto_date(chat.updated_at)
    }
  end

  def render("index.json", %{chats: chats} = opts) do
    render_many(chats, __MODULE__, "show.json", Map.delete(opts, :chats))
  end

  defp account_view_opts(opts, recipient) do
    account_view_opts = Map.put(opts, :user, recipient)

    if Map.has_key?(account_view_opts, :for) do
      account_view_opts
    else
      Map.put(account_view_opts, :skip_visibility_check, true)
    end
  end
end
