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
end
