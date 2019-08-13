# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MentionPolicy do
  @moduledoc "Block messages which mention a user"

  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(%{"type" => "Create"} = message) do
    reject_actors = Pleroma.Config.get([:mrf_mention, :actors], [])
    recipients = (message["to"] || []) ++ (message["cc"] || [])

    if Enum.any?(recipients, fn recipient -> Enum.member?(reject_actors, recipient) end) do
      {:reject, nil}
    else
      {:ok, message}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}
end
