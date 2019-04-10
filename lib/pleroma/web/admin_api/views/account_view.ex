# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.User.Info
  alias Pleroma.Web.AdminAPI.AccountView

  def render("index.json", %{users: users, count: count, page_size: page_size}) do
    %{
      users: render_many(users, AccountView, "show.json", as: :user),
      count: count,
      page_size: page_size
    }
  end

  def render("show.json", %{user: user}) do
    %{
      "id" => user.id,
      "nickname" => user.nickname,
      "deactivated" => user.info.deactivated,
      "local" => user.local,
      "roles" => Info.roles(user.info),
      "tags" => user.tags || []
    }
  end

  def render("invite.json", %{invite: invite}) do
    %{
      "id" => invite.id,
      "token" => invite.token,
      "used" => invite.used,
      "expires_at" => invite.expires_at,
      "uses" => invite.uses,
      "max_use" => invite.max_use,
      "invite_type" => invite.invite_type
    }
  end

  def render("invites.json", %{invites: invites}) do
    %{
      invites: render_many(invites, AccountView, "invite.json", as: :invite)
    }
  end
end
