defmodule Pleroma.Web.MastodonAPI.AccountViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.MastodonAPI.AccountView

  test "Represent a user account" do
    user = insert(:user, %{info: %{"note_count" => 5, "follower_count" => 3}})

    expected = %{
      id: user.id,
      username: user.nickname,
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: user.inserted_at,
      followers_count: 3,
      following_count: 0,
      statuses_count: 5,
      note: user.bio,
      url: user.ap_id,
      avatar: "https://placehold.it/48x48",
      avatar_static: "https://placehold.it/48x48",
      header: "",
      header_static: ""
    }

    assert expected == AccountView.render("account.json", %{user: user})
  end

  test "Represent a smaller mention" do
    user = insert(:user)

    expected = %{
      id: user.id,
      acct: user.nickname,
      username: user.nickname,
      url: user.ap_id
    }

    assert expected == AccountView.render("mention.json", %{user: user})
  end
end
