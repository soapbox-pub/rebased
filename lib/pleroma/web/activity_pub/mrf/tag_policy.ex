# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.TagPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp get_tags(%User{tags: tags}) when is_list(tags), do: tags
  defp get_tags(_), do: []

  defp process_tag(
         "mrf_tag:media-force-nsfw",
         %{"type" => "Create", "object" => %{"attachment" => child_attachment} = object} = message
       )
       when length(child_attachment) > 0 do
    tags = (object["tag"] || []) ++ ["nsfw"]

    object =
      object
      |> Map.put("tags", tags)
      |> Map.put("sensitive", true)

    message = Map.put(message, "object", object)

    {:ok, message}
  end

  defp process_tag(
         "mrf_tag:media-strip",
         %{"type" => "Create", "object" => %{"attachment" => child_attachment} = object} = message
       )
       when length(child_attachment) > 0 do
    object = Map.delete(object, "attachment")
    message = Map.put(message, "object", object)

    {:ok, message}
  end

  defp process_tag(_, message), do: {:ok, message}

  @impl true
  def filter(%{"actor" => actor} = message) do
    User.get_cached_by_ap_id(actor)
    |> get_tags()
    |> Enum.reduce({:ok, message}, fn
      tag, {:ok, message} ->
        process_tag(tag, message)

      _, error ->
        error
    end)
  end
end
