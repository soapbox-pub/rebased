# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.MailingListTest do
  alias Pleroma.User.MailingList

  use Pleroma.DataCase

  import Pleroma.Factory

  test "generate_csv/0" do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)

    expected = """
    Email Address
    #{user1.email}
    #{user2.email}
    #{user3.email}\
    """

    assert MailingList.generate_csv() == expected
  end
end
