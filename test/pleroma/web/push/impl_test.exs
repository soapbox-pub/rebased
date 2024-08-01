# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Push.ImplTest do
  use Pleroma.DataCase, async: true

  import ExUnit.CaptureLog
  import Mox
  import Pleroma.Factory

  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Push.Impl
  alias Pleroma.Web.Push.Subscription

  setup do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://example.com/example/1234"} ->
        %Tesla.Env{status: 200}

      %{method: :post, url: "https://example.com/example/not_found"} ->
        %Tesla.Env{status: 400}

      %{method: :post, url: "https://example.com/example/bad"} ->
        %Tesla.Env{status: 100}
    end)

    :ok
  end

  test "performs sending notifications" do
    user = insert(:user)
    user2 = insert(:user)
    insert(:push_subscription, user: user, data: %{alerts: %{"mention" => true}})
    insert(:push_subscription, user: user2, data: %{alerts: %{"mention" => true}})

    insert(:push_subscription,
      user: user,
      data: %{alerts: %{"follow" => true, "mention" => true}}
    )

    insert(:push_subscription,
      user: user,
      data: %{alerts: %{"follow" => true, "mention" => false}}
    )

    {:ok, activity} = CommonAPI.post(user, %{status: "<Lorem ipsum dolor sit amet."})

    notif =
      insert(:notification,
        user: user,
        activity: activity,
        type: "mention"
      )

    Impl.build(notif)
    |> Enum.each(fn push -> assert match?(:ok, Impl.deliver(push)) end)
  end

  test "returns error if notification activity type does not match" do
    assert capture_log(fn ->
             assert Impl.build(%{}) == []
           end) =~ "WebPush: unknown activity type"
  end

  test "fail message sending" do
    user = insert(:user)

    insert(:push_subscription,
      user: user,
      endpoint: "https://example.com/example/bad",
      data: %{alerts: %{"follow" => true}}
    )

    other_user = insert(:user)
    {:ok, _, _, activity} = CommonAPI.follow(other_user, user)

    notif =
      insert(:notification,
        user: user,
        activity: activity,
        type: "follow"
      )

    [push] = Impl.build(notif)

    assert Impl.deliver(push) == :error
  end

  test "delete subscription if result send message between 400..500" do
    user = insert(:user)

    bad_subscription =
      insert(:push_subscription,
        user: user,
        endpoint: "https://example.com/example/not_found",
        data: %{alerts: %{"follow" => true}}
      )

    other_user = insert(:user)
    {:ok, _, _, activity} = CommonAPI.follow(other_user, user)

    notif =
      insert(:notification,
        user: user,
        activity: activity,
        type: "follow"
      )

    [push] = Impl.build(notif)

    assert Impl.deliver(push) == :ok

    refute Pleroma.Repo.get(Subscription, bad_subscription.id)
  end

  test "deletes subscription when token has been deleted" do
    subscription = insert(:push_subscription)

    Pleroma.Repo.delete(subscription.token)

    refute Pleroma.Repo.get(Subscription, subscription.id)
  end

  test "renders title and body for create activity" do
    user = insert(:user, nickname: "Bob")

    {:ok, activity} =
      CommonAPI.post(user, %{
        status:
          "<span>Lorem ipsum dolor sit amet</span>, consectetur :firefox: adipiscing elit. Fusce sagittis finibus turpis."
      })

    object = Object.normalize(activity, fetch: false)

    assert Impl.format_body(
             %{
               activity: activity
             },
             user,
             object
           ) ==
             "@Bob: Lorem ipsum dolor sit amet, consectetur  adipiscing elit. Fusce sagittis finibus turpis."

    assert Impl.format_title(%{activity: activity, type: "mention"}) ==
             "New Mention"
  end

  test "renders title and body for follow activity" do
    user = insert(:user, nickname: "Bob")
    other_user = insert(:user)
    {:ok, _, _, activity} = CommonAPI.follow(other_user, user)
    object = Object.normalize(activity, fetch: false)

    assert Impl.format_body(%{activity: activity, type: "follow"}, user, object) ==
             "@Bob has followed you"

    assert Impl.format_title(%{activity: activity, type: "follow"}) ==
             "New Follower"
  end

  test "renders title and body for announce activity" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status:
          "<span>Lorem ipsum dolor sit amet</span>, consectetur :firefox: adipiscing elit. Fusce sagittis finibus turpis."
      })

    {:ok, announce_activity} = CommonAPI.repeat(activity.id, user)
    object = Object.normalize(activity, fetch: false)

    assert Impl.format_body(%{activity: announce_activity}, user, object) ==
             "@#{user.nickname} repeated: Lorem ipsum dolor sit amet, consectetur  adipiscing elit. Fusce sagittis finibus turpis."

    assert Impl.format_title(%{activity: announce_activity, type: "reblog"}) ==
             "New Repeat"
  end

  test "renders title and body for like activity" do
    user = insert(:user, nickname: "Bob")

    {:ok, activity} =
      CommonAPI.post(user, %{
        status:
          "<span>Lorem ipsum dolor sit amet</span>, consectetur :firefox: adipiscing elit. Fusce sagittis finibus turpis."
      })

    {:ok, activity} = CommonAPI.favorite(activity.id, user)
    object = Object.normalize(activity, fetch: false)

    assert Impl.format_body(%{activity: activity, type: "favourite"}, user, object) ==
             "@Bob has favorited your post"

    assert Impl.format_title(%{activity: activity, type: "favourite"}) ==
             "New Favorite"
  end

  test "renders title and body for pleroma:emoji_reaction activity" do
    user = insert(:user, nickname: "Bob")

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "This post is a really good post!"
      })

    {:ok, activity} = CommonAPI.react_with_emoji(activity.id, user, "👍")
    object = Object.normalize(activity, fetch: false)

    assert Impl.format_body(%{activity: activity, type: "pleroma:emoji_reaction"}, user, object) ==
             "@Bob reacted with 👍"

    assert Impl.format_title(%{activity: activity, type: "pleroma:emoji_reaction"}) ==
             "New Reaction"
  end

  test "renders title and body for update activity" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "lorem ipsum"})

    {:ok, activity} = CommonAPI.update(activity, user, %{status: "edited status"})
    object = Object.normalize(activity, fetch: false)

    assert Impl.format_body(%{activity: activity, type: "update"}, user, object) ==
             "@#{user.nickname} edited a status"

    assert Impl.format_title(%{activity: activity, type: "update"}) ==
             "New Update"
  end

  test "renders title for create activity with direct visibility" do
    user = insert(:user, nickname: "Bob")

    {:ok, activity} =
      CommonAPI.post(user, %{
        visibility: "direct",
        status: "This is just between you and me, pal"
      })

    assert Impl.format_title(%{activity: activity}) ==
             "New Direct Message"
  end

  test "renders poll notification" do
    user = insert(:user)
    question = insert(:question, user: user)
    activity = insert(:question_activity, question: question)

    {:ok, [notification]} = Notification.create_poll_notifications(activity)

    expected_title = "Poll Results"

    expected_body =
      """
      Which flavor of ice cream do you prefer?

      ○ chocolate
      ○ vanilla
      """
      |> String.trim_trailing("\n")

    content = Impl.build_content(notification, user, question)

    assert match?(%{title: ^expected_title, body: ^expected_body}, content)
  end

  describe "build_content/3" do
    test "builds content for chat messages" do
      user = insert(:user)
      recipient = insert(:user)

      {:ok, chat} = CommonAPI.post_chat_message(user, recipient, "hey")
      object = Object.normalize(chat, fetch: false)
      [notification] = Notification.for_user(recipient)

      res = Impl.build_content(notification, user, object)

      assert res == %{
               body: "@#{user.nickname}: hey",
               title: "New Chat Message"
             }
    end

    test "builds content for chat messages with no content" do
      user = insert(:user)
      recipient = insert(:user)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      ConfigMock
      |> stub_with(Pleroma.Test.StaticConfig)

      {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

      {:ok, chat} = CommonAPI.post_chat_message(user, recipient, nil, media_id: upload.id)
      object = Object.normalize(chat, fetch: false)
      [notification] = Notification.for_user(recipient)

      res = Impl.build_content(notification, user, object)

      assert res == %{
               body: "@#{user.nickname}: (Attachment)",
               title: "New Chat Message"
             }
    end

    test "hides contents of notifications when option enabled" do
      user = insert(:user, nickname: "Bob")

      user2 =
        insert(:user, nickname: "Rob", notification_settings: %{hide_notification_contents: true})

      {:ok, activity} =
        CommonAPI.post(user, %{
          visibility: "direct",
          status: "<Lorem ipsum dolor sit amet."
        })

      notif = insert(:notification, user: user2, activity: activity)

      actor = User.get_cached_by_ap_id(notif.activity.data["actor"])
      object = Object.normalize(activity, fetch: false)

      assert Impl.build_content(notif, actor, object) == %{
               body: "New Direct Message"
             }

      {:ok, activity} =
        CommonAPI.post(user, %{
          visibility: "public",
          status: "<Lorem ipsum dolor sit amet."
        })

      notif = insert(:notification, user: user2, activity: activity, type: "mention")

      actor = User.get_cached_by_ap_id(notif.activity.data["actor"])
      object = Object.normalize(activity, fetch: false)

      assert Impl.build_content(notif, actor, object) == %{
               body: "New Mention"
             }

      {:ok, activity} = CommonAPI.favorite(activity.id, user)

      notif = insert(:notification, user: user2, activity: activity, type: "favourite")

      actor = User.get_cached_by_ap_id(notif.activity.data["actor"])
      object = Object.normalize(activity, fetch: false)

      assert Impl.build_content(notif, actor, object) == %{
               body: "New Favorite"
             }
    end

    test "returns regular content when hiding contents option disabled" do
      user = insert(:user, nickname: "Bob")

      user2 =
        insert(:user,
          nickname: "Rob",
          notification_settings: %{hide_notification_contents: false}
        )

      {:ok, activity} =
        CommonAPI.post(user, %{
          visibility: "direct",
          status:
            "<span>Lorem ipsum dolor sit amet</span>, consectetur :firefox: adipiscing elit. Fusce sagittis finibus turpis."
        })

      notif = insert(:notification, user: user2, activity: activity)

      actor = User.get_cached_by_ap_id(notif.activity.data["actor"])
      object = Object.normalize(activity, fetch: false)

      assert Impl.build_content(notif, actor, object) == %{
               body:
                 "@Bob: Lorem ipsum dolor sit amet, consectetur  adipiscing elit. Fusce sagittis finibus turpis.",
               title: "New Direct Message"
             }

      {:ok, activity} =
        CommonAPI.post(user, %{
          visibility: "public",
          status:
            "<span>Lorem ipsum dolor sit amet</span>, consectetur :firefox: adipiscing elit. Fusce sagittis finibus turpis."
        })

      notif = insert(:notification, user: user2, activity: activity, type: "mention")

      actor = User.get_cached_by_ap_id(notif.activity.data["actor"])
      object = Object.normalize(activity, fetch: false)

      assert Impl.build_content(notif, actor, object) == %{
               body:
                 "@Bob: Lorem ipsum dolor sit amet, consectetur  adipiscing elit. Fusce sagittis finibus turpis.",
               title: "New Mention"
             }

      {:ok, activity} = CommonAPI.favorite(activity.id, user)

      notif = insert(:notification, user: user2, activity: activity, type: "favourite")

      actor = User.get_cached_by_ap_id(notif.activity.data["actor"])
      object = Object.normalize(activity, fetch: false)

      assert Impl.build_content(notif, actor, object) == %{
               body: "@Bob has favorited your post",
               title: "New Favorite"
             }
    end
  end

  test "build/1 notification payload body starts with nickname of actor the notification originated from" do
    user = insert(:user, nickname: "Bob")
    user2 = insert(:user, nickname: "Tom")
    insert(:push_subscription, user: user2, data: %{alerts: %{"mention" => true}})

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "@Tom Hey are you okay?"
      })

    {:ok, [notification]} = Notification.create_notifications(activity)

    [push] = Impl.build(notification)

    {:ok, payload} = Jason.decode(push.payload)

    assert String.starts_with?(payload["body"], "@Bob:")
  end
end
