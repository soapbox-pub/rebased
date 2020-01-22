# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.UserAllowListPolicy do
  alias Pleroma.Config

  @moduledoc "Accept-list of users from specified instances"
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp filter_by_list(object, []), do: {:ok, object}

  defp filter_by_list(%{"actor" => actor} = object, allow_list) do
    if actor in allow_list do
      {:ok, object}
    else
      {:reject, nil}
    end
  end

  @impl true
  def filter(%{"actor" => actor} = object) do
    actor_info = URI.parse(actor)

    allow_list =
      Config.get(
        [:mrf_user_allowlist, String.to_atom(actor_info.host)],
        []
      )

    filter_by_list(object, allow_list)
  end

  def filter(object), do: {:ok, object}

  @impl true
  def describe do
    mrf_user_allowlist =
      Config.get([:mrf_user_allowlist], [])
      |> Enum.into(%{}, fn {k, v} -> {k, length(v)} end)

    {:ok, %{mrf_user_allowlist: mrf_user_allowlist}}
  end
end
