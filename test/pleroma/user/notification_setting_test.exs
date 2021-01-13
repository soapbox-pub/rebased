# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.NotificationSettingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.User.NotificationSetting

  describe "changeset/2" do
    test "sets option to hide notification contents" do
      changeset =
        NotificationSetting.changeset(
          %NotificationSetting{},
          %{"hide_notification_contents" => true}
        )

      assert %Ecto.Changeset{valid?: true} = changeset
    end
  end
end
