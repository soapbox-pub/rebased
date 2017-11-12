defmodule Pleroma.NotificationTest do
  use Pleroma.DataCase
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.{User, Notification}
  import Pleroma.Factory

  describe "create_notifications" do
    test "notifies someone when they are directly addressed" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname} and @#{third_user.nickname}"})

      {:ok, [notification, other_notification]} = Notification.create_notifications(activity)

      assert notification.user_id == other_user.id
      assert notification.activity_id == activity.id
      assert other_notification.user_id == third_user.id
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
  end

  describe "get notification" do
    test "it gets a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.get(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, notification} = Notification.get(user, notification.id)
    end
  end

  describe "dismiss notification" do
    test "it dismisses a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.dismiss(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, notification} = Notification.dismiss(user, notification.id)
    end
  end

  describe "clear notification" do
    test "it clears all notifications belonging to the user" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey @#{other_user.nickname} and @#{third_user.nickname} !"})
      {:ok, _notifs} = Notification.create_notifications(activity)
      {:ok, activity} = TwitterAPI.create_status(user, %{"status" => "hey again @#{other_user.nickname} and @#{third_user.nickname} !"})
      {:ok, _notifs} = Notification.create_notifications(activity)
      Notification.clear(other_user)

      assert Notification.for_user(other_user) == []
      assert Notification.for_user(third_user) != []
    end
  end
end
