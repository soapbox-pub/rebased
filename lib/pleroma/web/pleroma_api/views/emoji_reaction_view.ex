# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiReactionView do
  use Pleroma.Web, :view

  alias Pleroma.Web.MastodonAPI.AccountView

  def render("index.json", %{emoji_reactions: emoji_reactions} = opts) do
    render_many(emoji_reactions, __MODULE__, "show.json", opts)
  end

  def render("show.json", %{emoji_reaction: {emoji, user_ap_ids}, user: user}) do
    users = fetch_users(user_ap_ids)

    %{
      name: emoji,
      count: length(users),
      accounts: render(AccountView, "index.json", users: users, for: user),
      me: !!(user && user.ap_id in user_ap_ids)
    }
  end

  defp fetch_users(user_ap_ids) do
    user_ap_ids
    |> Enum.map(&Pleroma.User.get_cached_by_ap_id/1)
    |> Enum.filter(fn
      %{is_active: true} -> true
      _ -> false
    end)
  end
end
