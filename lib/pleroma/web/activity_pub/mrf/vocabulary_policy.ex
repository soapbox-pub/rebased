# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.VocabularyPolicy do
  @moduledoc "Filter activities which belong to certain activity vocabularies"

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(%{"type" => "Undo", "object" => object} = activity) do
    with {:ok, _} <- filter(object) do
      {:ok, activity}
    else
      {:reject, _} = e -> e
    end
  end

  def filter(%{"type" => activity_type} = activity) do
    with accepted_vocabulary <- Pleroma.Config.get([:mrf_vocabulary, :accept]),
         rejected_vocabulary <- Pleroma.Config.get([:mrf_vocabulary, :reject]),
         {_, true} <-
           {:accepted,
            Enum.empty?(accepted_vocabulary) || Enum.member?(accepted_vocabulary, activity_type)},
         {_, false} <-
           {:rejected,
            length(rejected_vocabulary) > 0 && Enum.member?(rejected_vocabulary, activity_type)},
         {:ok, _} <- filter(activity["object"]) do
      {:ok, activity}
    else
      {:reject, _} = e -> e
      {:accepted, _} -> {:reject, "[VocabularyPolicy] #{activity_type} not in accept list"}
      {:rejected, _} -> {:reject, "[VocabularyPolicy] #{activity_type} in reject list"}
    end
  end

  def filter(activity), do: {:ok, activity}

  @impl true
  def describe,
    do: {:ok, %{mrf_vocabulary: Pleroma.Config.get(:mrf_vocabulary) |> Map.new()}}

  @impl true
  def config_description do
    %{
      key: :mrf_vocabulary,
      related_policy: "Pleroma.Web.ActivityPub.MRF.VocabularyPolicy",
      label: "MRF Vocabulary",
      description: "Filter activities which belong to certain activity vocabularies",
      children: [
        %{
          key: :accept,
          type: {:list, :string},
          description:
            "A list of ActivityStreams terms to accept. If empty, all supported activities are accepted.",
          suggestions: ["Create", "Follow", "Mention", "Announce", "Like"]
        },
        %{
          key: :reject,
          type: {:list, :string},
          description:
            "A list of ActivityStreams terms to reject. If empty, no activities are rejected.",
          suggestions: ["Create", "Follow", "Mention", "Announce", "Like"]
        }
      ]
    }
  end
end
