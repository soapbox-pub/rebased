# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.Feed do
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.Web.Router.Helpers

  @behaviour Provider

  @impl Provider
  def build_tags(%{user: user}) do
    [
      {:link,
       [
         rel: "alternate",
         type: "application/atom+xml",
         href: Helpers.user_feed_path(Endpoint, :feed, user.nickname) <> ".atom"
       ], []}
    ]
  end
end
