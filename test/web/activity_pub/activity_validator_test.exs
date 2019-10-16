# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidatorTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  describe "likes" do
    test "it is well formed" do
      _required_fields = [
        "id",
        "actor",
        "object"
      ]

      _user = insert(:user)
    end
  end
end
