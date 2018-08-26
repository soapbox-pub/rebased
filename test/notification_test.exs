defmodule Pleroma.NotificationTest do
  use Pleroma.DataCase
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.CommonAPI
  alias Pleroma.{User, Notification}
  import Pleroma.Factory

  describe "create_notifications" do
    test "notifies someone when they are directly addressed" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{
          "status" => "hey @#{other_user.nickname} and @#{third_user.nickname}"
        })

      {:ok, [notification, other_notification]} = Notification.create_notifications(activity)

      notified_ids = Enum.sort([notification.user_id, other_notification.user_id])
      assert notified_ids == [other_user.id, third_user.id]
      assert notification.activity_id == activity.id
      assert other_notification.activity_id == activity.id
    end
  end

  describe "create_notification" do
    test "it doesn't create a notification for user if the user blocks the activity author" do
      activity = insert(:note_activity)
      author = User.get_by_ap_id(activity.data["actor"])
      user = insert(:user)
      {:ok, user} = User.block(user, author)

      assert nil == Notification.create_notification(activity, user)
    end

    test "it doesn't create a notification for user if he is the activity author" do
      activity = insert(:note_activity)
      author = User.get_by_ap_id(activity.data["actor"])

      assert nil == Notification.create_notification(activity, author)
    end
  end

  describe "get notification" do
    test "it gets a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.get(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, _notification} = Notification.get(user, notification.id)
    end
  end

  describe "dismiss notification" do
    test "it dismisses a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.dismiss(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, _notification} = Notification.dismiss(user, notification.id)
    end
  end

  describe "clear notification" do
    test "it clears all notifications belonging to the user" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{
          "status" => "hey @#{other_user.nickname} and @#{third_user.nickname} !"
        })

      {:ok, _notifs} = Notification.create_notifications(activity)

      {:ok, activity} =
        TwitterAPI.create_status(user, %{
          "status" => "hey again @#{other_user.nickname} and @#{third_user.nickname} !"
        })

      {:ok, _notifs} = Notification.create_notifications(activity)
      Notification.clear(other_user)

      assert Notification.for_user(other_user) == []
      assert Notification.for_user(third_user) != []
    end
  end

  describe "notification lifecycle" do
    test "liking an activity results in 1 notification, then 0 if the activity is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert length(Notification.for_user(user)) == 0

      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert length(Notification.for_user(user)) == 0
    end

    test "liking an activity results in 1 notification, then 0 if the activity is unliked" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert length(Notification.for_user(user)) == 0

      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _, _, _} = CommonAPI.unfavorite(activity.id, other_user)

      assert length(Notification.for_user(user)) == 0
    end

    test "repeating an activity results in 1 notification, then 0 if the activity is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert length(Notification.for_user(user)) == 0

      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert length(Notification.for_user(user)) == 0
    end

    test "repeating an activity results in 1 notification, then 0 if the activity is unrepeated" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert length(Notification.for_user(user)) == 0

      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _, _} = CommonAPI.unrepeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 0
    end

    test "liking an activity which is already deleted does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert length(Notification.for_user(user)) == 0

      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      assert length(Notification.for_user(user)) == 0

      {:error, _} = CommonAPI.favorite(activity.id, other_user)

      assert length(Notification.for_user(user)) == 0
    end

    test "repeating an activity which is already deleted does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert length(Notification.for_user(user)) == 0

      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      assert length(Notification.for_user(user)) == 0

      {:error, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 0
    end

    test "replying to a deleted post without tagging does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})
      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      {:ok, _reply_activity} =
        CommonAPI.post(other_user, %{
          "status" => "test reply",
          "in_reply_to_status_id" => activity.id
        })

      assert length(Notification.for_user(user)) == 0
    end
  end
end
