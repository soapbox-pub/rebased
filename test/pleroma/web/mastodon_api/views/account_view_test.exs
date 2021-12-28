# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountViewTest do
  use Pleroma.DataCase

  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "Represent a user account" do
    background_image = %{
      "url" => [%{"href" => "https://example.com/images/asuka_hospital.png"}]
    }

    user =
      insert(:user, %{
        follower_count: 3,
        note_count: 5,
        background: background_image,
        nickname: "shp@shitposter.club",
        name: ":karjalanpiirakka: shp",
        bio:
          "<script src=\"invalid-html\"></script><span>valid html</span>. a<br>b<br/>c<br >d<br />f '&<>\"",
        inserted_at: ~N[2017-08-15 15:47:06.597036],
        emoji: %{"karjalanpiirakka" => "/file.png"},
        raw_bio: "valid html. a\nb\nc\nd\nf '&<>\"",
        also_known_as: ["https://shitposter.zone/users/shp"]
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
      note: "<span>valid html</span>. a<br/>b<br/>c<br/>d<br/>f &#39;&amp;&lt;&gt;&quot;",
      url: user.ap_id,
      avatar: "http://localhost:4001/images/avi.png",
      avatar_static: "http://localhost:4001/images/avi.png",
      header: "http://localhost:4001/images/banner.png",
      header_static: "http://localhost:4001/images/banner.png",
      emojis: [
        %{
          static_url: "/file.png",
          url: "/file.png",
          shortcode: "karjalanpiirakka",
          visible_in_picker: false
        }
      ],
      fields: [],
      bot: false,
      source: %{
        note: "valid html. a\nb\nc\nd\nf '&<>\"",
        sensitive: false,
        pleroma: %{
          actor_type: "Person",
          discoverable: true
        },
        fields: []
      },
      fqn: "shp@shitposter.club",
      last_status_at: nil,
      pleroma: %{
        ap_id: user.ap_id,
        also_known_as: ["https://shitposter.zone/users/shp"],
        background_image: "https://example.com/images/asuka_hospital.png",
        favicon: nil,
        is_confirmed: true,
        tags: [],
        is_admin: false,
        is_moderator: false,
        is_suggested: false,
        hide_favorites: true,
        hide_followers: false,
        hide_follows: false,
        hide_followers_count: false,
        hide_follows_count: false,
        relationship: %{},
        skip_thread_containment: false,
        accepts_chat_messages: nil
      }
    }

    assert expected == AccountView.render("show.json", %{user: user, skip_visibility_check: true})
  end

  describe "favicon" do
    setup do
      [user: insert(:user)]
    end

    test "is parsed when :instance_favicons is enabled", %{user: user} do
      clear_config([:instances_favicons, :enabled], true)

      assert %{
               pleroma: %{
                 favicon:
                   "https://shitposter.club/plugins/Qvitter/img/gnusocial-favicons/favicon-16x16.png"
               }
             } = AccountView.render("show.json", %{user: user, skip_visibility_check: true})
    end

    test "is nil when :instances_favicons is disabled", %{user: user} do
      assert %{pleroma: %{favicon: nil}} =
               AccountView.render("show.json", %{user: user, skip_visibility_check: true})
    end
  end

  test "Represent the user account for the account owner" do
    user = insert(:user)

    notification_settings = %{
      block_from_strangers: false,
      hide_notification_contents: false
    }

    privacy = user.default_scope

    assert %{
             pleroma: %{notification_settings: ^notification_settings, allow_following_move: true},
             source: %{privacy: ^privacy}
           } = AccountView.render("show.json", %{user: user, for: user})
  end

  test "Represent a Service(bot) account" do
    user =
      insert(:user, %{
        follower_count: 3,
        note_count: 5,
        actor_type: "Service",
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
          actor_type: "Service",
          discoverable: true
        },
        fields: []
      },
      fqn: "shp@shitposter.club",
      last_status_at: nil,
      pleroma: %{
        ap_id: user.ap_id,
        also_known_as: [],
        background_image: nil,
        favicon: nil,
        is_confirmed: true,
        tags: [],
        is_admin: false,
        is_moderator: false,
        is_suggested: false,
        hide_favorites: true,
        hide_followers: false,
        hide_follows: false,
        hide_followers_count: false,
        hide_follows_count: false,
        relationship: %{},
        skip_thread_containment: false,
        accepts_chat_messages: nil
      }
    }

    assert expected == AccountView.render("show.json", %{user: user, skip_visibility_check: true})
  end

  test "Represent a Funkwhale channel" do
    {:ok, user} =
      User.get_or_fetch_by_ap_id(
        "https://channels.tests.funkwhale.audio/federation/actors/compositions"
      )

    assert represented =
             AccountView.render("show.json", %{user: user, skip_visibility_check: true})

    assert represented.acct == "compositions@channels.tests.funkwhale.audio"
    assert represented.url == "https://channels.tests.funkwhale.audio/channels/compositions"
  end

  test "Represent a deactivated user for an admin" do
    admin = insert(:user, is_admin: true)
    deactivated_user = insert(:user, is_active: false)
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

  test "demands :for or :skip_visibility_check option for account rendering" do
    clear_config([:restrict_unauthenticated, :profiles, :local], false)

    user = insert(:user)
    user_id = user.id

    assert %{id: ^user_id} = AccountView.render("show.json", %{user: user, for: nil})
    assert %{id: ^user_id} = AccountView.render("show.json", %{user: user, for: user})

    assert %{id: ^user_id} =
             AccountView.render("show.json", %{user: user, skip_visibility_check: true})

    assert_raise RuntimeError, ~r/:skip_visibility_check or :for option is required/, fn ->
      AccountView.render("show.json", %{user: user})
    end
  end

  describe "relationship" do
    defp test_relationship_rendering(user, other_user, expected_result) do
      opts = %{user: user, target: other_user, relationships: nil}
      assert expected_result == AccountView.render("relationship.json", opts)

      relationships_opt = UserRelationship.view_relationships_option(user, [other_user])
      opts = Map.put(opts, :relationships, relationships_opt)
      assert expected_result == AccountView.render("relationship.json", opts)

      assert [expected_result] ==
               AccountView.render("relationships.json", %{user: user, targets: [other_user]})
    end

    @blank_response %{
      following: false,
      followed_by: false,
      blocking: false,
      blocked_by: false,
      muting: false,
      muting_notifications: false,
      subscribing: false,
      notifying: false,
      requested: false,
      domain_blocking: false,
      showing_reblogs: true,
      endorsed: false,
      note: ""
    }

    test "represent a relationship for the following and followed user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, user, other_user} = User.follow(user, other_user)
      {:ok, other_user, user} = User.follow(other_user, user)
      {:ok, _subscription} = User.subscribe(user, other_user)
      {:ok, _user_relationships} = User.mute(user, other_user, %{notifications: true})
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(user, other_user)

      expected =
        Map.merge(
          @blank_response,
          %{
            following: true,
            followed_by: true,
            muting: true,
            muting_notifications: true,
            subscribing: true,
            notifying: true,
            showing_reblogs: false,
            id: to_string(other_user.id)
          }
        )

      test_relationship_rendering(user, other_user, expected)
    end

    test "represent a relationship for the blocking and blocked user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, user, other_user} = User.follow(user, other_user)
      {:ok, _subscription} = User.subscribe(user, other_user)
      {:ok, _user_relationship} = User.block(user, other_user)
      {:ok, _user_relationship} = User.block(other_user, user)

      expected =
        Map.merge(
          @blank_response,
          %{following: false, blocking: true, blocked_by: true, id: to_string(other_user.id)}
        )

      test_relationship_rendering(user, other_user, expected)
    end

    test "represent a relationship for the user blocking a domain" do
      user = insert(:user)
      other_user = insert(:user, ap_id: "https://bad.site/users/other_user")

      {:ok, user} = User.block_domain(user, "bad.site")

      expected =
        Map.merge(
          @blank_response,
          %{domain_blocking: true, blocking: false, id: to_string(other_user.id)}
        )

      test_relationship_rendering(user, other_user, expected)
    end

    test "represent a relationship for the user with a pending follow request" do
      user = insert(:user)
      other_user = insert(:user, is_locked: true)

      {:ok, user, other_user, _} = CommonAPI.follow(user, other_user)
      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      expected =
        Map.merge(
          @blank_response,
          %{requested: true, following: false, id: to_string(other_user.id)}
        )

      test_relationship_rendering(user, other_user, expected)
    end
  end

  test "returns the settings store if the requesting user is the represented user and it's requested specifically" do
    user = insert(:user, pleroma_settings_store: %{fe: "test"})

    result =
      AccountView.render("show.json", %{user: user, for: user, with_pleroma_settings: true})

    assert result.pleroma.settings_store == %{:fe => "test"}

    result = AccountView.render("show.json", %{user: user, for: nil, with_pleroma_settings: true})
    assert result.pleroma[:settings_store] == nil

    result = AccountView.render("show.json", %{user: user, for: user})
    assert result.pleroma[:settings_store] == nil
  end

  test "doesn't sanitize display names" do
    user = insert(:user, name: "<marquee> username </marquee>")
    result = AccountView.render("show.json", %{user: user, skip_visibility_check: true})
    assert result.display_name == "<marquee> username </marquee>"
  end

  test "never display nil user follow counts" do
    user = insert(:user, following_count: 0, follower_count: 0)
    result = AccountView.render("show.json", %{user: user, skip_visibility_check: true})

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
             } = AccountView.render("show.json", %{user: user, skip_visibility_check: true})
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
             } = AccountView.render("show.json", %{user: user, skip_visibility_check: true})
    end

    test "shows actual follower/following count to the account owner" do
      user = insert(:user, hide_followers: true, hide_follows: true)
      other_user = insert(:user)
      {:ok, user, other_user, _activity} = CommonAPI.follow(user, other_user)

      assert User.following?(user, other_user)
      assert Pleroma.FollowingRelationship.follower_count(other_user) == 1
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
          status: "Hey @#{user.nickname}.",
          visibility: "direct"
        })

      user = User.get_cached_by_ap_id(user.ap_id)

      assert AccountView.render("show.json", %{user: user, for: other_user})[:pleroma][
               :unread_conversation_count
             ] == nil

      assert AccountView.render("show.json", %{user: user, for: user})[:pleroma][
               :unread_conversation_count
             ] == 1
    end

    test "shows unread_count only to the account owner" do
      user = insert(:user)
      insert_list(7, :notification, user: user, activity: insert(:note_activity))
      other_user = insert(:user)

      user = User.get_cached_by_ap_id(user.ap_id)

      assert AccountView.render(
               "show.json",
               %{user: user, for: other_user}
             )[:pleroma][:unread_notifications_count] == nil

      assert AccountView.render(
               "show.json",
               %{user: user, for: user}
             )[:pleroma][:unread_notifications_count] == 7
    end

    test "shows email only to the account owner" do
      user = insert(:user)
      other_user = insert(:user)

      user = User.get_cached_by_ap_id(user.ap_id)

      assert AccountView.render(
               "show.json",
               %{user: user, for: other_user}
             )[:pleroma][:email] == nil

      assert AccountView.render(
               "show.json",
               %{user: user, for: user}
             )[:pleroma][:email] == user.email
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
      user = insert(:user, is_locked: true)

      assert %{locked: true} = AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      assert %{locked: true, follow_requests_count: 1} =
               AccountView.render("show.json", %{user: user, for: user})
    end

    test "decreases when accepting a follow request" do
      user = insert(:user, is_locked: true)

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
      user = insert(:user, is_locked: true)

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
      user = insert(:user, is_locked: true)

      assert %{locked: true} = AccountView.render("show.json", %{user: user, for: user})

      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      {:ok, user} = User.update_and_set_cache(user, %{is_locked: false})

      assert %{locked: false, follow_requests_count: 1} =
               AccountView.render("show.json", %{user: user, for: user})
    end
  end

  test "uses mediaproxy urls when it's enabled (regardless of media preview proxy state)" do
    clear_config([:media_proxy, :enabled], true)
    clear_config([:media_preview_proxy, :enabled])

    user =
      insert(:user,
        avatar: %{"url" => [%{"href" => "https://evil.website/avatar.png"}]},
        banner: %{"url" => [%{"href" => "https://evil.website/banner.png"}]},
        emoji: %{"joker_smile" => "https://evil.website/society.png"}
      )

    with media_preview_enabled <- [false, true] do
      clear_config([:media_preview_proxy, :enabled], media_preview_enabled)

      AccountView.render("show.json", %{user: user, skip_visibility_check: true})
      |> Enum.all?(fn
        {key, url} when key in [:avatar, :avatar_static, :header, :header_static] ->
          String.starts_with?(url, Pleroma.Web.Endpoint.url())

        {:emojis, emojis} ->
          Enum.all?(emojis, fn %{url: url, static_url: static_url} ->
            String.starts_with?(url, Pleroma.Web.Endpoint.url()) &&
              String.starts_with?(static_url, Pleroma.Web.Endpoint.url())
          end)

        _ ->
          true
      end)
      |> assert()
    end
  end
end
