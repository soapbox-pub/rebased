# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.NotificationSettingTest do
  use Pleroma.DataCase

  alias Pleroma.User.NotificationSetting

  describe "changeset/2" do
    test "sets valid privacy option" do
      changeset =
        NotificationSetting.changeset(
          %NotificationSetting{},
          %{"privacy_option" => true}
        )

      assert %Ecto.Changeset{valid?: true} = changeset
    end
  end
end
