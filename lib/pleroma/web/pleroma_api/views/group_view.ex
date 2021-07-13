# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.GroupView do
  use Pleroma.Web, :view

  alias Pleroma.Group
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.PleromaAPI.GroupView

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

  def render("show.json", _), do: nil

  def render("relationship.json", %{user: %User{} = user, group: %Group{} = group}) do
    membership_state = Group.get_membership_state(group, user)

    IO.inspect(membership_state)

    %{
      id: group.id,
      # TODO: Make dynamic
      requested: membership_state == :join_pending,
      admin: false,
      moderator: false,
      owner: user.id == group.owner_id,
      member: Group.is_member?(group, user)
    }
  end

  def render("relationships.json", %{user: user, groups: groups}) do
    render_many(groups, GroupView, "relationship.json", user: user)
  end

  def render("status.json", params), do: StatusView.render("show.json", params)
  def render("statuses.json", params), do: StatusView.render("index.json", params)

  # TODO: Remove these. Just placeholders for now.
  def render("empty_array.json", _), do: []
  def render("empty_object.json", _), do: %{}
end
