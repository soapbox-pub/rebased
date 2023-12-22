# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiReactionView do
  use Pleroma.Web, :view

  alias Pleroma.Web.MastodonAPI.AccountView

  def emoji_name(emoji, nil), do: emoji

  def emoji_name(emoji, url) do
    url = URI.parse(url)

    if url.host == Pleroma.Web.Endpoint.host() do
      emoji
    else
      "#{emoji}@#{url.host}"
    end
  end

  def render("index.json", %{emoji_reactions: emoji_reactions} = opts) do
    render_many(emoji_reactions, __MODULE__, "show.json", opts)
  end

  def render("show.json", %{emoji_reaction: {emoji, user_ap_ids, url}, user: user}) do
    users = fetch_users(user_ap_ids)

    %{
      name: emoji_name(emoji, url),
      count: length(users),
      accounts: render(AccountView, "index.json", users: users, for: user),
      url: Pleroma.Web.MediaProxy.url(url),
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
