defmodule Pleroma.UserInfoTest do
  alias Pleroma.Repo
  alias Pleroma.User.Info

  use Pleroma.DataCase

  import Pleroma.Factory

  describe "update_email_notifications/2" do
    setup do
      user = insert(:user, %{info: %{email_notifications: %{"digest" => true}}})

      {:ok, user: user}
    end

    test "Notifications are updated", %{user: user} do
      true = user.info.email_notifications["digest"]
      changeset = Info.update_email_notifications(user.info, %{"digest" => false})
      assert changeset.valid?
      {:ok, result} = Ecto.Changeset.apply_action(changeset, :insert)
      assert result.email_notifications["digest"] == false
    end
  end
end
