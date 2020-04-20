# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatMessageView do
  use Pleroma.Web, :view

  alias Pleroma.Chat
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.StatusView

  def render(
        "show.json",
        %{
          object: %{id: id, data: %{"type" => "ChatMessage"} = chat_message},
          chat: %Chat{id: chat_id}
        }
      ) do
    %{
      id: id |> to_string(),
      content: chat_message["content"],
      chat_id: chat_id |> to_string(),
      actor: chat_message["actor"],
      created_at: Utils.to_masto_date(chat_message["published"]),
      emojis: StatusView.build_emojis(chat_message["emoji"])
    }
  end

  def render("index.json", opts) do
    render_many(opts[:objects], __MODULE__, "show.json", Map.put(opts, :as, :object))
  end
end
