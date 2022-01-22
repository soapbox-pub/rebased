# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMentionsInContent do
  alias Pleroma.Formatter
  alias Pleroma.User

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp do_extract({:a, attrs, _}, acc) do
    if Enum.find(attrs, fn {name, value} ->
         name == "class" && value in ["mention", "u-url mention", "mention u-url"]
       end) do
      href = Enum.find(attrs, fn {name, _} -> name == "href" end) |> elem(1)
      acc ++ [href]
    else
      acc
    end
  end

  defp do_extract({_, _, children}, acc) do
    do_extract(children, acc)
  end

  defp do_extract(nodes, acc) when is_list(nodes) do
    Enum.reduce(nodes, acc, fn node, acc -> do_extract(node, acc) end)
  end

  defp do_extract(_, acc), do: acc

  defp extract_mention_uris_from_content(content) do
    {:ok, tree} = :fast_html.decode(content, format: [:html_atoms])
    do_extract(tree, [])
  end

  @impl true
  def filter(%{"type" => "Create", "object" => %{"type" => "Note", "tag" => tag}} = object) do
    # image-only posts from pleroma apparently reach this MRF without the content field
    content = object["object"]["content"] || ""

    mention_users =
      tag
      |> Enum.filter(fn tag -> tag["type"] == "Mention" end)
      |> Enum.map(& &1["href"])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn ap_id_or_uri ->
        case User.get_or_fetch_by_ap_id(ap_id_or_uri) do
          {:ok, user} -> {ap_id_or_uri, user}
          _ -> {ap_id_or_uri, User.get_by_uri(ap_id_or_uri)}
        end
      end)
      |> Enum.reject(fn {_, user} -> user == nil end)
      |> Enum.into(%{})

    explicitly_mentioned_uris = extract_mention_uris_from_content(content)

    added_mentions =
      Enum.reduce(mention_users, "", fn {uri, user}, acc ->
        unless uri in explicitly_mentioned_uris do
          acc <> Formatter.mention_from_user(user)
        else
          acc
        end
      end)

    content =
      if added_mentions != "",
        do: added_mentions <> " " <> content,
        else: content

    {:ok, put_in(object["object"]["content"], content)}
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}
end
