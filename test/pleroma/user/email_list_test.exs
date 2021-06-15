# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.EmailListTest do
  alias Pleroma.User.EmailList

  use Pleroma.DataCase

  import Pleroma.Factory

  test "generate_csv/0" do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)

    expected = """
    Email Address\r
    #{user1.email}\r
    #{user2.email}\r
    #{user3.email}\r
    """

    assert EmailList.generate_csv() == expected
  end
end
