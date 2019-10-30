# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.UserRepresenter do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.StaticFE.ActivityRepresenter

  def prepare_user(%User{} = user) do
    %{}
    |> set_user(user)
    |> set_timeline(user)
  end

  defp set_user(data, %User{} = user), do: Map.put(data, :user, user)

  defp set_timeline(data, %User{} = user) do
    activities =
      ActivityPub.fetch_user_activities(user, nil, %{})
      |> Enum.map(fn activity -> ActivityRepresenter.prepare_activity(user, activity) end)

    Map.put(data, :timeline, activities)
  end

  def represent(username_or_id) do
    case User.get_cached_by_nickname_or_id(username_or_id) do
      %User{} = user -> {:ok, prepare_user(user)}
      nil -> {:error, "User not found"}
    end
  end
end
