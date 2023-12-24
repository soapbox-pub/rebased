# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.InternalFetchActor do
  alias Pleroma.User

  require Logger

  def init do
    # Wait for everything to settle.
    Process.sleep(1000 * 5)
    get_actor()
    get_actor(Pleroma.Web.Endpoint.url())
  end

  def get_actor(origin) do
    %URI{host: host} = URI.parse(origin)

    nickname =
      cond do
        host == Pleroma.Web.Endpoint.host() -> "internal.fetch"
        true -> "internal.fetch@#{host}"
      end

    "#{origin}/internal/fetch"
    |> User.get_or_create_service_actor_by_ap_id(nickname)
  end

  def get_actor() do
    (Pleroma.Config.get([:activitypub, :fetch_actor_origin]) || Pleroma.Web.Endpoint.url())
    |> get_actor()
  end
end
