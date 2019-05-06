# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.RejectNonPublic do
  alias Pleroma.User
  @moduledoc "Rejects non-public (followers-only, direct) activities"
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(%{"type" => "Create"} = object) do
    user = User.get_cached_by_ap_id(object["actor"])
    public = "https://www.w3.org/ns/activitystreams#Public"

    # Determine visibility
    visibility =
      cond do
        public in object["to"] -> "public"
        public in object["cc"] -> "unlisted"
        user.follower_address in object["to"] -> "followers"
        true -> "direct"
      end

    policy = Pleroma.Config.get(:mrf_rejectnonpublic)

    case visibility do
      "public" ->
        {:ok, object}

      "unlisted" ->
        {:ok, object}

      "followers" ->
        with true <- Keyword.get(policy, :allow_followersonly) do
          {:ok, object}
        else
          _e -> {:reject, nil}
        end

      "direct" ->
        with true <- Keyword.get(policy, :allow_direct) do
          {:ok, object}
        else
          _e -> {:reject, nil}
        end
    end
  end

  @impl true
  def filter(object), do: {:ok, object}
end
