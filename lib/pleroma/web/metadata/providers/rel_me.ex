# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RelMe do
  alias Pleroma.Web.Metadata.Providers.Provider
  @behaviour Provider

  @impl Provider
  def build_tags(%{user: user}) do
    profile_tree =
      user.bio
      |> append_fields_tag(user.fields)
      |> Floki.parse_fragment!()

    (Floki.attribute(profile_tree, "link[rel~=me]", "href") ++
       Floki.attribute(profile_tree, "a[rel~=me]", "href"))
    |> Enum.map(fn link ->
      {:link, [rel: "me", href: link], []}
    end)
  end

  @impl Provider
  def build_tags(_), do: []

  defp append_fields_tag(bio, fields) do
    fields
    |> Enum.reduce(bio, fn %{"value" => v}, res -> res <> v end)
  end
end
