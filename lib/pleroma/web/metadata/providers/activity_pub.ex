# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.ActivityPub do
  alias Pleroma.Web.Metadata.Providers.Provider

  @behaviour Provider

  @impl Provider
  def build_tags(%{object: %{data: %{"id" => object_id}}}) do
    [{:link, [rel: "alternate", type: "application/activity+json", href: object_id], []}]
  end

  @impl Provider
  def build_tags(%{user: user}) do
    [{:link, [rel: "alternate", type: "application/activity+json", href: user.ap_id], []}]
  end

  @impl Provider
  def build_tags(_), do: []
end
