# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RelMe do
  alias Pleroma.Web.Metadata.Providers.Provider
  @behaviour Provider

  @impl Provider
  def build_tags(%{user: user}) do
    profile_tree =
      Floki.parse_fragment!(user.bio)
      |> prepend_fields_tag(user.fields)

    (Floki.attribute(profile_tree, "link[rel~=me]", "href") ++
       Floki.attribute(profile_tree, "a[rel~=me]", "href"))
    |> Enum.map(fn link ->
      {:link, [rel: "me", href: link], []}
    end)
  end

  defp prepend_fields_tag(bio_tree, fields) do
    fields
    |> Enum.reduce(bio_tree, fn %{"value" => v}, tree ->
      case Floki.parse_fragment(v) do
        {:ok, [a | _]} -> [a | tree]
        _ -> tree
      end
    end)
  end
end
