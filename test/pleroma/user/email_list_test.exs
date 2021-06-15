# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.EmailListTest do
  alias Pleroma.User.EmailList

  use Pleroma.DataCase

  import Pleroma.Factory

  test "generate_csv/1 with :subscribers" do
    user1 = insert(:user, accepts_email_list: true)
    user2 = insert(:user, accepts_email_list: true)
    user3 = insert(:user, accepts_email_list: true)
    insert(:user, accepts_email_list: false)

    expected = """
    Email Address,Nickname,Subscribe?\r
    #{user1.email},#{user1.nickname},true\r
    #{user2.email},#{user2.nickname},true\r
    #{user3.email},#{user3.nickname},true\r
    """

    assert EmailList.generate_csv(:subscribers) == expected
  end

  test "generate_csv/1 with :unsubscribers" do
    user1 = insert(:user, accepts_email_list: false)
    user2 = insert(:user, accepts_email_list: false)
    insert(:user, accepts_email_list: true)
    insert(:user, accepts_email_list: true)

    expected = """
    Email Address,Nickname,Subscribe?\r
    #{user1.email},#{user1.nickname},false\r
    #{user2.email},#{user2.nickname},false\r
    """

    assert EmailList.generate_csv(:unsubscribers) == expected
  end
end
