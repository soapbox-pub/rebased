# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI

  def render(
        "participation_requests.json",
        %{participation_requests: participation_requests} = opts
      ) do
    render_many(
      participation_requests,
      __MODULE__,
      "participation_request.json",
      Map.delete(opts, :participation_requests)
    )
  end

  def render("participation_request.json", %{participation_request: participation_request} = opts) do
    %{}
  end
end
