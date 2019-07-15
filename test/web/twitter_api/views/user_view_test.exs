# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UserViewTest do
  use Pleroma.DataCase

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.UserView

  import Pleroma.Factory

  setup do
    user = insert(:user, bio: "<span>Here's some html</span>")
    [user: user]
  end

  test "A user with only a nickname", %{user: user} do
    user = %{user | name: nil, nickname: "scarlett@catgirl.science"}
    represented = UserView.render("show.json", %{user: user})
    assert represented["name"] == user.nickname
    assert represented["name_html"] == user.nickname
  end

  test "A user with an avatar object", %{user: user} do
    image = "image"
    user = %{user | avatar: %{"url" => [%{"href" => image}]}}
    represented = UserView.render("show.json", %{user: user})
    assert represented["profile_image_url"] == image
  end

  test "A user with emoji in username" do
    expected =
      "<img class=\"emoji\" alt=\"karjalanpiirakka\" title=\"karjalanpiirakka\" src=\"/file.png\" /> man"

    user =
      insert(:user, %{
        info: %{
          source_data: %{
            "tag" => [
              %{
                "type" => "Emoji",
                "icon" => %{"url" => "/file.png"},
                "name" => ":karjalanpiirakka:"
              }
            ]
          }
        },
        name: ":karjalanpiirakka: man"
      })

    represented = UserView.render("show.json", %{user: user})
    assert represented["name_html"] == expected
  end

  test "A user" do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])
    {:ok, user} = User.update_note_count(user)
    follower = insert(:user)
    second_follower = insert(:user)

    User.follow(follower, user)
    User.follow(second_follower, user)
    User.follow(user, follower)
    {:ok, user} = User.update_follower_count(user)
    Cachex.put(:user_cache, "user_info:#{user.id}", User.user_info(Repo.get!(User, user.id)))

    image = "http://localhost:4001/images/avi.png"
    banner = "http://localhost:4001/images/banner.png"

    represented = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "name_html" => user.name,
      "description" => HtmlSanitizeEx.strip_tags(user.bio |> String.replace("<br>", "\n")),
      "description_html" => HtmlSanitizeEx.basic_html(user.bio),
      "created_at" => user.inserted_at |> Utils.format_naive_asctime(),
      "favourites_count" => 0,
      "statuses_count" => 1,
      "friends_count" => 1,
      "followers_count" => 2,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "following" => false,
      "follows_you" => false,
      "statusnet_blocking" => false,
      "statusnet_profile_url" => user.ap_id,
      "cover_photo" => banner,
      "background_image" => nil,
      "is_local" => true,
      "locked" => false,
      "hide_follows" => false,
      "hide_followers" => false,
      "fields" => [],
      "pleroma" => %{
        "confirmation_pending" => false,
        "tags" => [],
        "skip_thread_containment" => false
      },
      "rights" => %{"admin" => false, "delete_others_notice" => false},
      "role" => "member"
    }

    assert represented == UserView.render("show.json", %{user: user})
  end

  test "User exposes settings for themselves and only for themselves", %{user: user} do
    as_user = UserView.render("show.json", %{user: user, for: user})
    assert as_user["default_scope"] == user.info.default_scope
    assert as_user["no_rich_text"] == user.info.no_rich_text
    assert as_user["pleroma"]["notification_settings"] == user.info.notification_settings
    as_stranger = UserView.render("show.json", %{user: user})
    refute as_stranger["default_scope"]
    refute as_stranger["no_rich_text"]
    refute as_stranger["pleroma"]["notification_settings"]
  end

  test "A user for a given other follower", %{user: user} do
    follower = insert(:user, %{following: [User.ap_followers(user)]})
    {:ok, user} = User.update_follower_count(user)
    image = "http://localhost:4001/images/avi.png"
    banner = "http://localhost:4001/images/banner.png"

    represented = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "name_html" => user.name,
      "description" => HtmlSanitizeEx.strip_tags(user.bio |> String.replace("<br>", "\n")),
      "description_html" => HtmlSanitizeEx.basic_html(user.bio),
      "created_at" => user.inserted_at |> Utils.format_naive_asctime(),
      "favourites_count" => 0,
      "statuses_count" => 0,
      "friends_count" => 0,
      "followers_count" => 1,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "following" => true,
      "follows_you" => false,
      "statusnet_blocking" => false,
      "statusnet_profile_url" => user.ap_id,
      "cover_photo" => banner,
      "background_image" => nil,
      "is_local" => true,
      "locked" => false,
      "hide_follows" => false,
      "hide_followers" => false,
      "fields" => [],
      "pleroma" => %{
        "confirmation_pending" => false,
        "tags" => [],
        "skip_thread_containment" => false
      },
      "rights" => %{"admin" => false, "delete_others_notice" => false},
      "role" => "member"
    }

    assert represented == UserView.render("show.json", %{user: user, for: follower})
  end

  test "A user that follows you", %{user: user} do
    follower = insert(:user)
    {:ok, follower} = User.follow(follower, user)
    {:ok, user} = User.update_follower_count(user)
    image = "http://localhost:4001/images/avi.png"
    banner = "http://localhost:4001/images/banner.png"

    represented = %{
      "id" => follower.id,
      "name" => follower.name,
      "screen_name" => follower.nickname,
      "name_html" => follower.name,
      "description" => HtmlSanitizeEx.strip_tags(follower.bio |> String.replace("<br>", "\n")),
      "description_html" => HtmlSanitizeEx.basic_html(follower.bio),
      "created_at" => follower.inserted_at |> Utils.format_naive_asctime(),
      "favourites_count" => 0,
      "statuses_count" => 0,
      "friends_count" => 1,
      "followers_count" => 0,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "following" => false,
      "follows_you" => true,
      "statusnet_blocking" => false,
      "statusnet_profile_url" => follower.ap_id,
      "cover_photo" => banner,
      "background_image" => nil,
      "is_local" => true,
      "locked" => false,
      "hide_follows" => false,
      "hide_followers" => false,
      "fields" => [],
      "pleroma" => %{
        "confirmation_pending" => false,
        "tags" => [],
        "skip_thread_containment" => false
      },
      "rights" => %{"admin" => false, "delete_others_notice" => false},
      "role" => "member"
    }

    assert represented == UserView.render("show.json", %{user: follower, for: user})
  end

  test "a user that is a moderator" do
    user = insert(:user, %{info: %{is_moderator: true}})
    represented = UserView.render("show.json", %{user: user, for: user})

    assert represented["rights"]["delete_others_notice"]
    assert represented["role"] == "moderator"
  end

  test "a user that is a admin" do
    user = insert(:user, %{info: %{is_admin: true}})
    represented = UserView.render("show.json", %{user: user, for: user})

    assert represented["rights"]["admin"]
    assert represented["role"] == "admin"
  end

  test "A moderator with hidden role for another user", %{user: user} do
    admin = insert(:user, %{info: %{is_moderator: true, show_role: false}})
    represented = UserView.render("show.json", %{user: admin, for: user})

    assert represented["role"] == nil
  end

  test "An admin with hidden role for another user", %{user: user} do
    admin = insert(:user, %{info: %{is_admin: true, show_role: false}})
    represented = UserView.render("show.json", %{user: admin, for: user})

    assert represented["role"] == nil
  end

  test "A regular user for the admin", %{user: user} do
    admin = insert(:user, %{info: %{is_admin: true}})
    represented = UserView.render("show.json", %{user: user, for: admin})

    assert represented["pleroma"]["deactivated"] == false
  end

  test "A blocked user for the blocker" do
    user = insert(:user)
    blocker = insert(:user)
    User.block(blocker, user)
    image = "http://localhost:4001/images/avi.png"
    banner = "http://localhost:4001/images/banner.png"

    represented = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "name_html" => user.name,
      "description" => HtmlSanitizeEx.strip_tags(user.bio |> String.replace("<br>", "\n")),
      "description_html" => HtmlSanitizeEx.basic_html(user.bio),
      "created_at" => user.inserted_at |> Utils.format_naive_asctime(),
      "favourites_count" => 0,
      "statuses_count" => 0,
      "friends_count" => 0,
      "followers_count" => 0,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "following" => false,
      "follows_you" => false,
      "statusnet_blocking" => true,
      "statusnet_profile_url" => user.ap_id,
      "cover_photo" => banner,
      "background_image" => nil,
      "is_local" => true,
      "locked" => false,
      "hide_follows" => false,
      "hide_followers" => false,
      "fields" => [],
      "pleroma" => %{
        "confirmation_pending" => false,
        "tags" => [],
        "skip_thread_containment" => false
      },
      "rights" => %{"admin" => false, "delete_others_notice" => false},
      "role" => "member"
    }

    blocker = User.get_cached_by_id(blocker.id)
    assert represented == UserView.render("show.json", %{user: user, for: blocker})
  end

  test "a user with mastodon fields" do
    fields = [
      %{
        "name" => "Pronouns",
        "value" => "she/her"
      },
      %{
        "name" => "Website",
        "value" => "https://example.org/"
      }
    ]

    user =
      insert(:user, %{
        info: %{
          source_data: %{
            "attachment" =>
              Enum.map(fields, fn field -> Map.put(field, "type", "PropertyValue") end)
          }
        }
      })

    userview = UserView.render("show.json", %{user: user})
    assert userview["fields"] == fields
  end
end
