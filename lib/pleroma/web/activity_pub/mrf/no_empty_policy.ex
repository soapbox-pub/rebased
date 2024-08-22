# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoEmptyPolicy do
  @moduledoc "Filter local activities which have no content"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Web.Endpoint

  @impl true
  def filter(%{"actor" => actor} = activity) do
    with true <- local?(actor),
         true <- eligible_type?(activity),
         true <- note?(activity),
         false <- has_attachment?(activity),
         true <- only_mentions?(activity) do
      {:reject, "[NoEmptyPolicy]"}
    else
      _ ->
        {:ok, activity}
    end
  end

  def filter(activity), do: {:ok, activity}

  defp local?(actor) do
    if actor |> String.starts_with?("#{Endpoint.url()}") do
      true
    else
      false
    end
  end

  defp has_attachment?(%{
         "object" => %{"type" => "Note", "attachment" => attachments}
       })
       when length(attachments) > 0,
       do: true

  defp has_attachment?(_), do: false

  defp only_mentions?(%{"object" => %{"type" => "Note", "source" => source}}) do
    source =
      case source do
        %{"content" => text} -> text
        _ -> source
      end

    non_mentions =
      source |> String.split() |> Enum.filter(&(not String.starts_with?(&1, "@"))) |> length

    if non_mentions > 0 do
      false
    else
      true
    end
  end

  defp only_mentions?(_), do: false

  defp note?(%{"object" => %{"type" => "Note"}}), do: true
  defp note?(_), do: false

  defp eligible_type?(%{"type" => type}) when type in ["Create", "Update"], do: true
  defp eligible_type?(_), do: false

  @impl true
  def describe, do: {:ok, %{}}
end
