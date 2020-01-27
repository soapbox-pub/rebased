# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.UserViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.CommonAPI

  test "Renders a user, including the public key" do
    user = insert(:user)
    {:ok, user} = User.ensure_keys_present(user)

    result = UserView.render("user.json", %{user: user})

    assert result["id"] == user.ap_id
    assert result["preferredUsername"] == user.nickname

    assert String.contains?(result["publicKey"]["publicKeyPem"], "BEGIN PUBLIC KEY")
  end

  test "Renders profile fields" do
    fields = [
      %{"name" => "foo", "value" => "bar"}
    ]

    {:ok, user} =
      insert(:user)
      |> User.upgrade_changeset(%{fields: fields})
      |> User.update_and_set_cache()

    assert %{
             "attachment" => [%{"name" => "foo", "type" => "PropertyValue", "value" => "bar"}]
           } = UserView.render("user.json", %{user: user})
  end

  test "Renders with emoji tags" do
    user = insert(:user, emoji: [%{"bib" => "/test"}])

    assert %{
             "tag" => [
               %{
                 "icon" => %{"type" => "Image", "url" => "/test"},
                 "id" => "/test",
                 "name" => ":bib:",
                 "type" => "Emoji",
                 "updated" => "1970-01-01T00:00:00Z"
               }
             ]
           } = UserView.render("user.json", %{user: user})
  end

  test "Does not add an avatar image if the user hasn't set one" do
    user = insert(:user)
    {:ok, user} = User.ensure_keys_present(user)

    result = UserView.render("user.json", %{user: user})
    refute result["icon"]
    refute result["image"]

    user =
      insert(:user,
        avatar: %{"url" => [%{"href" => "https://someurl"}]},
        banner: %{"url" => [%{"href" => "https://somebanner"}]}
      )

    {:ok, user} = User.ensure_keys_present(user)

    result = UserView.render("user.json", %{user: user})
    assert result["icon"]["url"] == "https://someurl"
    assert result["image"]["url"] == "https://somebanner"
  end

  test "renders an invisible user with the invisible property set to true" do
    user = insert(:user, invisible: true)

    assert %{"invisible" => true} = UserView.render("service.json", %{user: user})
  end

  describe "endpoints" do
    test "local users have a usable endpoints structure" do
      user = insert(:user)
      {:ok, user} = User.ensure_keys_present(user)

      result = UserView.render("user.json", %{user: user})

      assert result["id"] == user.ap_id

      %{
        "sharedInbox" => _,
        "oauthAuthorizationEndpoint" => _,
        "oauthRegistrationEndpoint" => _,
        "oauthTokenEndpoint" => _
      } = result["endpoints"]
    end

    test "remote users have an empty endpoints structure" do
      user = insert(:user, local: false)
      {:ok, user} = User.ensure_keys_present(user)

      result = UserView.render("user.json", %{user: user})

      assert result["id"] == user.ap_id
      assert result["endpoints"] == %{}
    end

    test "instance users do not expose oAuth endpoints" do
      user = insert(:user, nickname: nil, local: true)
      {:ok, user} = User.ensure_keys_present(user)

      result = UserView.render("user.json", %{user: user})

      refute result["endpoints"]["oauthAuthorizationEndpoint"]
      refute result["endpoints"]["oauthRegistrationEndpoint"]
      refute result["endpoints"]["oauthTokenEndpoint"]
    end
  end

  describe "followers" do
    test "sets totalItems to zero when followers are hidden" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)
      assert %{"totalItems" => 1} = UserView.render("followers.json", %{user: user})
      user = Map.merge(user, %{hide_followers_count: true, hide_followers: true})
      refute UserView.render("followers.json", %{user: user}) |> Map.has_key?("totalItems")
    end

    test "sets correct totalItems when followers are hidden but the follower counter is not" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)
      assert %{"totalItems" => 1} = UserView.render("followers.json", %{user: user})
      user = Map.merge(user, %{hide_followers_count: false, hide_followers: true})
      assert %{"totalItems" => 1} = UserView.render("followers.json", %{user: user})
    end
  end

  describe "following" do
    test "sets totalItems to zero when follows are hidden" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, user, _other_user, _activity} = CommonAPI.follow(user, other_user)
      assert %{"totalItems" => 1} = UserView.render("following.json", %{user: user})
      user = Map.merge(user, %{hide_follows_count: true, hide_follows: true})
      assert %{"totalItems" => 0} = UserView.render("following.json", %{user: user})
    end

    test "sets correct totalItems when follows are hidden but the follow counter is not" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, user, _other_user, _activity} = CommonAPI.follow(user, other_user)
      assert %{"totalItems" => 1} = UserView.render("following.json", %{user: user})
      user = Map.merge(user, %{hide_follows_count: false, hide_follows: true})
      assert %{"totalItems" => 1} = UserView.render("following.json", %{user: user})
    end
  end

  test "activity collection page aginates correctly" do
    user = insert(:user)

    posts =
      for i <- 0..25 do
        {:ok, activity} = CommonAPI.post(user, %{"status" => "post #{i}"})
        activity
      end

    # outbox sorts chronologically, newest first, with ten per page
    posts = Enum.reverse(posts)

    %{"next" => next_url} =
      UserView.render("activity_collection_page.json", %{
        iri: "#{user.ap_id}/outbox",
        activities: Enum.take(posts, 10)
      })

    next_id = Enum.at(posts, 9).id
    assert next_url =~ next_id

    %{"next" => next_url} =
      UserView.render("activity_collection_page.json", %{
        iri: "#{user.ap_id}/outbox",
        activities: Enum.take(Enum.drop(posts, 10), 10)
      })

    next_id = Enum.at(posts, 19).id
    assert next_url =~ next_id
  end
end
