# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.VocabularyPolicy do
  @moduledoc "Filter messages which belong to certain activity vocabularies"

  @behaviour Pleroma.Web.ActivityPub.MRF

  def filter(%{"type" => "Undo", "object" => child_message} = message) do
    with {:ok, _} <- filter(child_message) do
      {:ok, message}
    else
      {:reject, nil} ->
        {:reject, nil}
    end
  end

  def filter(%{"type" => message_type} = message) do
    with accepted_vocabulary <- Pleroma.Config.get([:mrf_vocabulary, :accept]),
         rejected_vocabulary <- Pleroma.Config.get([:mrf_vocabulary, :reject]),
         true <-
           Enum.empty?(accepted_vocabulary) || Enum.member?(accepted_vocabulary, message_type),
         false <-
           length(rejected_vocabulary) > 0 && Enum.member?(rejected_vocabulary, message_type),
         {:ok, _} <- filter(message["object"]) do
      {:ok, message}
    else
      _ -> {:reject, nil}
    end
  end

  def filter(message), do: {:ok, message}

  def describe,
    do: {:ok, %{mrf_vocabulary: Pleroma.Config.get(:mrf_vocabulary) |> Enum.into(%{})}}
end
