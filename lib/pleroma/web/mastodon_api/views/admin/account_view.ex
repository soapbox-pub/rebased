# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.Admin.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.User.Info
  alias Pleroma.Web.MastodonAPI.Admin.AccountView

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
      "roles" => Info.roles(user.info)
    }
  end
end
