defmodule Pleroma.Web.MastodonAPI.AccountView do
  use Pleroma.Web, :view
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.CommonAPI.Utils

  defp image_url(%{"url" => [ %{ "href" => href } | t ]}), do: href
  defp image_url(_), do: nil

  def render("accounts.json", %{users: users} = opts) do
    render_many(users, AccountView, "account.json", opts)
  end

  def render("account.json", %{user: user}) do
    image = User.avatar_url(user)
    user_info = User.user_info(user)

    header = image_url(user.info["banner"]) || "https://placehold.it/700x335"

    %{
      id: to_string(user.id),
      username: hd(String.split(user.nickname, "@")),
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: Utils.to_masto_date(user.inserted_at),
      followers_count: user_info.follower_count,
      following_count: user_info.following_count,
      statuses_count: user_info.note_count,
      note: user.bio || "",
      url: user.ap_id,
      avatar: image,
      avatar_static: image,
      header: header,
      header_static: header,
      source: %{
        note: "",
        privacy: "public",
        sensitive: "false"
      }
    }
  end

  def render("mention.json", %{user: user}) do
    %{
      id: to_string(user.id),
      acct: user.nickname,
      username: hd(String.split(user.nickname, "@")),
      url: user.ap_id
    }
  end

  def render("relationship.json", %{user: user, target: target}) do
    %{
      id: to_string(target.id),
      following: User.following?(user, target),
      followed_by: User.following?(target, user),
      blocking: User.blocks?(user, target),
      muting: false,
      requested: false,
      domain_blocking: false
    }
  end

  def render("relationships.json", %{user: user, targets: targets}) do
    render_many(targets, AccountView, "relationship.json", user: user, as: :target)
  end
end
