# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.UserAllowListPolicy do
  alias Pleroma.Config

  @moduledoc "Accept-list of users from specified instances"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp filter_by_list(object, []), do: {:ok, object}

  defp filter_by_list(%{"actor" => actor} = object, allow_list) do
    if actor in allow_list do
      {:ok, object}
    else
      {:reject, "[UserAllowListPolicy] #{actor} not in the list"}
    end
  end

  @impl true
  def filter(%{"actor" => actor} = object) do
    actor_info = URI.parse(actor)

    allow_list =
      Config.get(
        [:mrf_user_allowlist, actor_info.host],
        []
      )

    filter_by_list(object, allow_list)
  end

  def filter(object), do: {:ok, object}

  @impl true
  def describe do
    mrf_user_allowlist =
      Config.get([:mrf_user_allowlist], [])
      |> Map.new(fn {k, v} -> {k, length(v)} end)

    {:ok, %{mrf_user_allowlist: mrf_user_allowlist}}
  end

  # TODO: change way of getting settings on `lib/pleroma/web/activity_pub/mrf/user_allow_list_policy.ex:18` to use `hosts` subkey
  # @impl true
  # def config_description do
  #   %{
  #     key: :mrf_user_allowlist,
  #     related_policy: "Pleroma.Web.ActivityPub.MRF.UserAllowListPolicy",
  #     description: "Accept-list of users from specified instances",
  #     children: [
  #       %{
  #         key: :hosts,
  #         type: :map,
  #         description:
  #           "The keys in this section are the domain names that the policy should apply to." <>
  #             " Each key should be assigned a list of users that should be allowed " <>
  #             "through by their ActivityPub ID",
  #         suggestions: [%{"example.org" => ["https://example.org/users/admin"]}]
  #       }
  #     ]
  #   }
  # end
end
