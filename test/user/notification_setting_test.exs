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
          %{"privacy_option" => "name_only"}
        )

      assert %Ecto.Changeset{valid?: true} = changeset
    end

    test "returns invalid changeset when privacy option is incorrect" do
      changeset =
        NotificationSetting.changeset(
          %NotificationSetting{},
          %{"privacy_option" => "full_content"}
        )

      assert %Ecto.Changeset{valid?: false} = changeset

      assert [
               privacy_option:
                 {"is invalid",
                  [
                    validation: :inclusion,
                    enum: ["name_and_message", "name_only", "no_name_or_message"]
                  ]}
             ] = changeset.errors
    end
  end
end
