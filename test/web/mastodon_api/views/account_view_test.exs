# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView

  test "Represent a user account" do
    source_data = %{
      "tag" => [
        %{
          "type" => "Emoji",
          "icon" => %{"url" => "/file.png"},
          "name" => ":karjalanpiirakka:"
        }
      ]
    }

    background_image = %{
      "url" => [%{"href" => "https://example.com/images/asuka_hospital.png"}]
    }

    user =
      insert(:user, %{
        follower_count: 3,
        note_count: 5,
        source_data: source_data,
        background: background_image,
        nickname: "shp@shitposter.club",
        name: ":karjalanpiirakka: shp",
        bio: "<script src=\"invalid-html\"></script><span>valid html</span>",
        inserted_at: ~N[2017-08-15 15:47:06.597036]
      })

    expected = %{
      id: to_string(user.id),
      username: "shp",
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: "2017-08-15T15:47:06.000Z",
      followers_count: 3,
      following_count: 0,
      statuses_count: 5,
      note: "<span>valid html</span>",
      url: user.ap_id,
      avatar: "http://localhost:4001/images/avi.png",
      avatar_static: "http://localhost:4001/images/avi.png",
      header: "http://localhost:4001/images/banner.png",
      header_static: "http://localhost:4001/images/banner.png",
      emojis: [
        %{
          "static_url" => "/file.png",
          "url" => "/file.png",
          "shortcode" => "karjalanpiirakka",
          "visible_in_picker" => false
        }
      ],
      fields: [],
      bot: false,
      source: %{
        note: "valid html",
        sensitive: false,
        pleroma: %{
          discoverable: false
        },
        fields: []
      },
      pleroma: %{
        background_image: "https://example.com/images/asuka_hospital.png",
        confirmation_pending: false,
        tags: [],
        is_admin: false,
        is_moderator: false,
        hide_favorites: true,
        hide_followers: false,
        hide_follows: false,
        hide_followers_count: false,
        hide_follows_count: false,
        relationship: %{},
        skip_thread_containment: false
      }
    }

    assert expected == AccountView.render("show.json", %{user: user})
  end

  test "Represent the user account for the account owner" do
    user = insert(:user)

    notification_settings = %{
      "followers" => true,
      "follows" => true,
      "non_follows" => true,
      "non_followers" => true
    }

    privacy = user.default_scope

    assert %{
             pleroma: %{notification_settings: ^notification_settings},
             source: %{privacy: ^privacy}
           } = AccountView.render("show.json", %{user: user, for: user})
  end

  test "Represent a Service(bot) account" do
    user =
      insert(:user, %{
        follower_count: 3,
        note_count: 5,
        source_data: %{"type" => "Service"},
        nickname: "shp@shitposter.club",
        inserted_at: ~N[2017-08-15 15:47:06.597036]
      })

    expected = %{
      id: to_string(user.id),
      username: "shp",
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: "2017-08-15T15:47:06.000Z",
      followers_count: 3,
      following_count: 0,
      statuses_count: 5,
      note: user.bio,
      url: user.ap_id,
      avatar: "http://localhost:4001/images/avi.png",
      avatar_static: "http://localhost:4001/images/avi.png",
      header: "http://localhost:4001/images/banner.png",
      header_static: "http://localhost:4001/images/banner.png",
      emojis: [],
      fields: [],
      bot: true,
      source: %{
        note: user.bio,
        sensitive: false,
        pleroma: %{
          discoverable: false
        },
        fields: []
      },
      pleroma: %{
        background_image: nil,
        confirmation_pending: false,
        tags: [],
        is_admin: false,
        is_moderator: false,
        hide_favorites: true,
        hide_followers: false,
        hide_follows: false,
        hide_followers_count: false,
        hide_follows_count: false,
        relationship: %{},
        skip_thread_containment: false
      }
    }

    assert expected == AccountView.render("show.json", %{user: user})
  end

  test "Represent a deactivated user for an admin" do
    admin = insert(:user, is_admin: true)
    deactivated_user = insert(:user, deactivated: true)
    represented = AccountView.render("show.json", %{user: deactivated_user, for: admin})
    assert represented[:pleroma][:deactivated] == true
  end

  test "Represent a smaller mention" do
    user = insert(:user)

    expected = %{
      id: to_string(user.id),
      acct: user.nickname,
      username: user.nickname,
      url: user.ap_id
    }

    assert expected == AccountView.render("mention.json", %{user: user})
  end

  describe "relationship" do
    test "represent a relationship for the following and followed user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, user} = User.follow(user, other_user)
      {:ok, other_user} = User.follow(other_user, user)
      {:ok, other_user} = User.subscribe(user, other_user)
      {:ok, user} = User.mute(user, other_user, true)
      {:ok, user} = CommonAPI.hide_reblogs(user, other_user)

      expected = %{
        id: to_string(other_user.id),
        following: true,
        followed_by: true,
        blocking: false,
        blocked_by: false,
        muting: true,
        muting_notifications: true,
        subscribing: true,
        requested: false,
        domain_blocking: false,
        showing_reblogs: false,
        endorsed: false
      }

      assert expected ==
               AccountView.render("relationship.json", %{user: user, target: other_user})
    end

    test "represent a relationship for the blocking and blocked user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, user} = User.follow(user, other_user)
      {:ok, other_user} = User.subscribe(user, other_user)
      {:ok, user} = User.block(user, other_user)
      {:ok, other_user} = User.block(other_user, user)

      expected = %{
        id: to_string(other_user.id),
        following: false,
        followed_by: false,
        blocking: true,
        blocked_by: true,
        muting: false,
        muting_notifications: false,
        subscribing: false,
        requested: false,
        domain_blocking: false,
        showing_reblogs: true,
        endorsed: false
      }

      assert expected ==
               AccountView.render("relationship.json", %{user: user, target: other_user})
    end

    test "represent a relationship for the user blocking a domain" do
      user = insert(:user)
      other_user = insert(:user, ap_id: "https://bad.site/users/other_user")

      {:ok, user} = User.block_domain(user, "bad.site")

      assert %{domain_blocking: true, blocking: false} =
               AccountView.render("relationship.json", %{user: user, target: other_user})
    end

    test "represent a relationship for the user with a pending follow request" do
      user = insert(:user)
      other_user = insert(:user, locked: true)

      {:ok, user, other_user, _} = CommonAPI.follow(user, other_user)
      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      expected = %{
        id: to_string(other_user.id),
        following: false,
        followed_by: false,
        blocking: false,
        blocked_by: false,
        muting: false,
        muting_notifications: false,
        subscribing: false,
        requested: true,
        domain_blocking: false,
        showing_reblogs: true,
        endorsed: false
      }

      assert expected ==
               AccountView.render("relationship.json", %{user: user, target: other_user})
    end
  end

  test "represent an embedded relationship" do
    user =
      insert(:user, %{
        follower_count: 0,
        note_count: 5,
        source_data: %{"type" => "Service"},
        nickname: "shp@shitposter.club",
        inserted_at: ~N[2017-08-15 15:47:06.597036]
      })

    other_user = insert(:user)
    {:ok, other_user} = User.follow(other_user, user)
    {:ok, other_user} = User.block(other_user, user)
    {:ok, _} = User.follow(insert(:user), user)

    expected = %{
      id: to_string(user.id),
      username: "shp",
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: "2017-08-15T15:47:06.000Z",
      followers_count: 1,
      following_count: 0,
      statuses_count: 5,
      note: user.bio,
      url: user.ap_id,
      avatar: "http://localhost:4001/images/avi.png",
      avatar_static: "http://localhost:4001/images/avi.png",
      header: "http://localhost:4001/images/banner.png",
      header_static: "http://localhost:4001/images/banner.png",
      emojis: [],
      fields: [],
      bot: true,
      source: %{
        note: user.bio,
        sensitive: false,
        pleroma: %{
          discoverable: false
        },
        fields: []
      },
      pleroma: %{
        background_image: nil,
        confirmation_pending: false,
        tags: [],
        is_admin: false,
        is_moderator: false,
        hide_favorites: true,
        hide_followers: false,
        hide_follows: false,
        hide_followers_count: false,
        hide_follows_count: false,
        relationship: %{
          id: to_string(user.id),
          following: false,
          followed_by: false,
          blocking: true,
          blocked_by: false,
          subscribing: false,
          muting: false,
          muting_notifications: false,
          requested: false,
          domain_blocking: false,
          showing_reblogs: true,
          endorsed: false
        },
        skip_thread_containment: false
      }
    }

    assert expected ==
             AccountView.render("show.json", %{user: refresh_record(user), for: other_user})
  end

  test "returns the settings store if the requesting user is the represented user and it's requested specifically" do
    user = insert(:user, pleroma_settings_store: %{fe: "test"})

    result =
      AccountView.render("show.json", %{user: user, for: user, with_pleroma_settings: true})

    assert result.pleroma.settings_store == %{:fe => "test"}

    result = AccountView.render("show.json", %{user: user, with_pleroma_settings: true})
    assert result.pleroma[:settings_store] == nil

    result = AccountView.render("show.json", %{user: user, for: user})
    assert result.pleroma[:settings_store] == nil
  end

  test "sanitizes display names" do
    user = insert(:user, name: "<marquee> username </marquee>")
    result = AccountView.render("show.json", %{user: user})
    refute result.display_name == "<marquee> username </marquee>"
  end

  test "never display nil user follow counts" do
    user = insert(:user, following_count: 0, follower_count: 0)
    result = AccountView.render("show.json", %{user: user})

    assert result.following_count == 0
    assert result.followers_count == 0
  end

  describe "hiding follows/following" do
    test "shows when follows/followers stats are hidden and sets follow/follower count to 0" do
      user =
        insert(:user, %{
          hide_followers: true,
          hide_followers_count: true,
          hide_follows: true,
          hide_follows_count: true
        })

      other_user = insert(:user)
      {:ok, user, other_user, _activity} = CommonAPI.follow(user, other_user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{
               followers_count: 0,
               following_count: 0,
               pleroma: %{hide_follows_count: true, hide_followers_count: true}
             } = AccountView.render("show.json", %{user: user})
    end

    test "shows when follows/followers are hidden" do
      user = insert(:user, hide_followers: true, hide_follows: true)
      other_user = insert(:user)
      {:ok, user, other_user, _activity} = CommonAPI.follow(user, other_user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{
               followers_count: 1,
               following_count: 1,
               pleroma: %{hide_follows: true, hide_followers: true}
             } = AccountView.render("show.json", %{user: user})
    end

    test "shows actual follower/following count to the account owner" do
      user = insert(:user, hide_followers: true, hide_follows: true)
      other_user = insert(:user)
      {:ok, user, other_user, _activity} = CommonAPI.follow(user, other_user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{
               followers_count: 1,
               following_count: 1
             } = AccountView.render("show.json", %{user: user, for: user})
    end

    test "shows unread_conversation_count only to the account owner" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} =
        CommonAPI.post(other_user, %{
          "status" => "Hey @#{user.nickname}.",
          "visibility" => "direct"
        })

      user = User.get_cached_by_ap_id(user.ap_id)

      assert AccountView.render("show.json", %{user: user, for: other_user})[:pleroma][
               :unread_conversation_count
             ] == nil

      assert AccountView.render("show.json", %{user: user, for: user})[:pleroma][
               :unread_conversation_count
             ] == 1
    end
  end

  describe "follow requests counter" do
    test "shows zero when no follow requests are pending" do
      user = insert(:user)

      assert %{follow_requests_count: 0} =
               AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{follow_requests_count: 0} =
               AccountView.render("show.json", %{user: user, for: user})
    end

    test "shows non-zero when follow requests are pending" do
      user = insert(:user, locked: true)

      assert %{locked: true} = AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{locked: true, follow_requests_count: 1} =
               AccountView.render("show.json", %{user: user, for: user})
    end

    test "decreases when accepting a follow request" do
      user = insert(:user, locked: true)

      assert %{locked: true} = AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{locked: true, follow_requests_count: 1} =
               AccountView.render("show.json", %{user: user, for: user})

      {:ok, _other_user} = CommonAPI.accept_follow_request(other_user, user)

      assert %{locked: true, follow_requests_count: 0} =
               AccountView.render("show.json", %{user: user, for: user})
    end

    test "decreases when rejecting a follow request" do
      user = insert(:user, locked: true)

      assert %{locked: true} = AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{locked: true, follow_requests_count: 1} =
               AccountView.render("show.json", %{user: user, for: user})

      {:ok, _other_user} = CommonAPI.reject_follow_request(other_user, user)

      assert %{locked: true, follow_requests_count: 0} =
               AccountView.render("show.json", %{user: user, for: user})
    end

    test "shows non-zero when historical unapproved requests are present" do
      user = insert(:user, locked: true)

      assert %{locked: true} = AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      {:ok, user} = User.update_and_set_cache(user, %{locked: false})

      assert %{locked: false, follow_requests_count: 1} =
               AccountView.render("show.json", %{user: user, for: user})
    end
  end
end
