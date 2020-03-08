# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.InternalFetchActor do
  alias Pleroma.User

  require Logger

  def init do
    # Wait for everything to settle.
    Process.sleep(1000 * 5)
    get_actor()
  end

  def get_actor do
    "#{Pleroma.Web.Endpoint.url()}/internal/fetch"
    |> User.get_or_create_service_actor_by_ap_id("internal.fetch")
  end
end
