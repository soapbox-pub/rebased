# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.Chat.MessageReferenceView do
  use Pleroma.Web, :view

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.StatusView

  def render(
        "show.json",
        %{
          chat_message_reference: %{
            id: id,
            object: %{data: chat_message} = object,
            chat_id: chat_id,
            unread: unread
          }
        }
      ) do
    %{
      id: id |> to_string(),
      content: chat_message["content"],
      chat_id: chat_id |> to_string(),
      account_id: User.get_cached_by_ap_id(chat_message["actor"]).id,
      created_at: Utils.to_masto_date(chat_message["published"]),
      emojis: StatusView.build_emojis(chat_message["emoji"]),
      attachment:
        chat_message["attachment"] &&
          StatusView.render("attachment.json", attachment: chat_message["attachment"]),
      unread: unread,
      card:
        StatusView.render(
          "card.json",
          Pleroma.Web.RichMedia.Helpers.fetch_data_for_object(object)
        )
    }
  end

  def render("index.json", opts) do
    render_many(
      opts[:chat_message_references],
      __MODULE__,
      "show.json",
      Map.put(opts, :as, :chat_message_reference)
    )
  end
end
