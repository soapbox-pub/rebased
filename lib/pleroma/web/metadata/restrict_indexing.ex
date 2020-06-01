# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RestrictIndexing do
  @behaviour Pleroma.Web.Metadata.Providers.Provider

  @moduledoc """
  Restricts indexing of remote users.
  """

  @impl true
  def build_tags(%{user: %{local: false}}) do
    [
      {:meta,
       [
         name: "robots",
         content: "noindex, noarchive"
       ], []}
    ]
  end

  @impl true
  def build_tags(%{user: %{local: true}}), do: []
end
