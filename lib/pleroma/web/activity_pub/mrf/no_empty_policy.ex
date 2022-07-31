# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoEmptyPolicy do
  @moduledoc "Filter local activities which have no content"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Web.Endpoint

  @impl true
  def filter(%{"actor" => actor} = object) do
    with true <- is_local?(actor),
         true <- is_note?(object),
         false <- has_attachment?(object),
         true <- only_mentions?(object) do
      {:reject, "[NoEmptyPolicy]"}
    else
      _ ->
        {:ok, object}
    end
  end

  def filter(object), do: {:ok, object}

  defp is_local?(actor) do
    if actor |> String.starts_with?("#{Endpoint.url()}") do
      true
    else
      false
    end
  end

  defp has_attachment?(%{
         "type" => "Create",
         "object" => %{"type" => "Note", "attachment" => attachments}
       })
       when length(attachments) > 0,
       do: true

  defp has_attachment?(_), do: false

  defp only_mentions?(%{"type" => "Create", "object" => %{"type" => "Note", "source" => source}}) do
    non_mentions =
      source |> String.split() |> Enum.filter(&(not String.starts_with?(&1, "@"))) |> length

    if non_mentions > 0 do
      false
    else
      true
    end
  end

  defp only_mentions?(_), do: false

  defp is_note?(%{"type" => "Create", "object" => %{"type" => "Note"}}), do: true
  defp is_note?(_), do: false

  @impl true
  def describe, do: {:ok, %{}}
end
