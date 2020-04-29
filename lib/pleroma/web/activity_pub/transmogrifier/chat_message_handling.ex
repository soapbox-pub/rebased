# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.ChatMessageHandling do
  alias Pleroma.Web.ActivityPub.Pipeline

  def handle_incoming(
        %{"type" => "Create", "object" => %{"type" => "ChatMessage"}} = data,
        _options
      ) do
    case Pipeline.common_pipeline(data, local: false) do
      {:ok, activity, _} ->
        {:ok, activity}

      e ->
        e
    end
  end
end
