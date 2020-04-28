# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.ChatMessageHandling do
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.Pipeline

  def handle_incoming(
        %{"type" => "Create", "object" => %{"type" => "ChatMessage"}} = data,
        _options
      ) do
    # Create has to be run inside a transaction because the object is created as a side effect.
    # If this does not work, we need to roll back creating the activity.
    case Repo.transaction(fn -> Pipeline.common_pipeline(data, local: false) end) do
      {:ok, {:ok, activity, _}} ->
        {:ok, activity}

      {:ok, e} ->
        e

      {:error, e} ->
        {:error, e}
    end
  end
end
