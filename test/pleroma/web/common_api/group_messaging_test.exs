# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.GroupMessagingTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Group
  alias Pleroma.Web.CommonAPI

  describe "Group chats" do
    test "local chat" do
      user = insert(:user)

      {:ok, group_creation_activity} =
        CommonAPI.create_group(user, %{name: "cofe", description: "for cofe enthusiasts"})

      group = Group.get_for_object(group_creation_activity)

      assert group
    end
  end
end
