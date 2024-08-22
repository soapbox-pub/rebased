# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MentionPolicy do
  @moduledoc "Block activities which mention a user"

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(%{"type" => "Create"} = activity) do
    reject_actors = Pleroma.Config.get([:mrf_mention, :actors], [])
    recipients = (activity["to"] || []) ++ (activity["cc"] || [])

    if rejected_mention =
         Enum.find(recipients, fn recipient -> Enum.member?(reject_actors, recipient) end) do
      {:reject, "[MentionPolicy] Rejected for mention of #{rejected_mention}"}
    else
      {:ok, activity}
    end
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_mention,
      related_policy: "Pleroma.Web.ActivityPub.MRF.MentionPolicy",
      label: "MRF Mention",
      description: "Block activities which mention a specific user",
      children: [
        %{
          key: :actors,
          type: {:list, :string},
          description: "A list of actors for which any post mentioning them will be dropped",
          suggestions: ["actor1", "actor2"]
        }
      ]
    }
  end
end
