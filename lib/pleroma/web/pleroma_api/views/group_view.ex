# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.GroupView do
  use Pleroma.Web, :view

  alias Pleroma.Group
  alias Pleroma.Repo
  alias Pleroma.User

  def render("show.json", %{group: %Group{} = group}) do
    group = Repo.preload(group, :user)

    %{
      id: group.id,
      # TODO: handle remote accts
      acct: group.user.nickname,
      slug: group.user.nickname,
      avatar: User.avatar_url(group.user),
      header: User.banner_url(group.user),
      created_at: group.inserted_at,
      display_name: group.name,
      emojis: [],
      fields: [],
      # TODO: get proper count
      members_count: Group.members(group) |> Enum.count(),
      locked: group.user.is_locked,
      note: group.description,
      url: group.ap_id,
      source: %{
        fields: [],
        note: group.description,
        privacy: group.privacy
      }
    }
  end
end
