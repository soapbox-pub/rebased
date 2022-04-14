# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RestrictIndexing do
  @behaviour Pleroma.Web.Metadata.Providers.Provider

  @moduledoc """
  Restricts indexing of remote and/or non-discoverable users.
  """

  @impl true
  def build_tags(%{user: %{local: true, is_discoverable: true}}), do: []

  def build_tags(_) do
    [
      {:meta,
       [
         name: "robots",
         content: "noindex, noarchive"
       ], []}
    ]
  end
end
