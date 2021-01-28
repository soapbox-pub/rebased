# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.GroupValidationTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator

  describe "Group objects" do
    test "it validates a group" do
      user = insert(:user)

      {:ok, group_data, []} = Builder.group(user, "a group", "a description")

      {:ok, group, _} = ObjectValidator.validate(group_data, [])

      assert group
    end
  end
end
