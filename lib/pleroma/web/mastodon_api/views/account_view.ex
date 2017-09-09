defmodule Pleroma.Web.MastodonAPI.AccountView do
  use Pleroma.Web, :view
  alias Pleroma.User

  def render("account.json", %{user: user}) do
    image = User.avatar_url(user)
    user_info = User.user_info(user)

    %{
      id: user.id,
      username: user.nickname,
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: user.inserted_at,
      followers_count: user_info.follower_count,
      following_count: user_info.following_count,
      statuses_count: user_info.note_count,
      note: user.bio,
      url: user.ap_id,
      avatar: image,
      avatar_static: image,
      header: "",
      header_static: ""
    }
  end

  def render("mention.json", %{user: user}) do
    %{
      id: user.id,
      acct: user.nickname,
      username: user.nickname,
      url: user.ap_id
    }
  end
end
