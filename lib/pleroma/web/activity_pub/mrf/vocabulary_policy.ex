# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.VocabularyPolicy do
  @moduledoc "Filter messages which belong to certain activity vocabularies"

  @behaviour Pleroma.Web.ActivityPub.MRF

  def filter(%{"type" => "Undo", "object" => child_message} = message) do
    with {:ok, _} <- filter(child_message) do
      {:ok, message}
    else
      {:reject, _} = e -> e
    end
  end

  def filter(%{"type" => message_type} = message) do
    with accepted_vocabulary <- Pleroma.Config.get([:mrf_vocabulary, :accept]),
         rejected_vocabulary <- Pleroma.Config.get([:mrf_vocabulary, :reject]),
         {_, true} <-
           {:accepted,
            Enum.empty?(accepted_vocabulary) || Enum.member?(accepted_vocabulary, message_type)},
         {_, false} <-
           {:rejected,
            length(rejected_vocabulary) > 0 && Enum.member?(rejected_vocabulary, message_type)},
         {:ok, _} <- filter(message["object"]) do
      {:ok, message}
    else
      {:reject, _} = e -> e
      {:accepted, _} -> {:reject, "[VocabularyPolicy] #{message_type} not in accept list"}
      {:rejected, _} -> {:reject, "[VocabularyPolicy] #{message_type} in reject list"}
      _ -> {:reject, "[VocabularyPolicy]"}
    end
  end

  def filter(message), do: {:ok, message}

  def describe,
    do: {:ok, %{mrf_vocabulary: Pleroma.Config.get(:mrf_vocabulary) |> Enum.into(%{})}}
end
