# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.DigestEmailDaemonTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Daemons.DigestEmailDaemon
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  test "it sends digest emails" do
    user = insert(:user)

    date =
      Timex.now()
      |> Timex.shift(days: -10)
      |> Timex.to_naive_datetime()

    user2 = insert(:user, last_digest_emailed_at: date)
    {:ok, _} = User.switch_email_notifications(user2, "digest", true)
    CommonAPI.post(user, %{"status" => "hey @#{user2.nickname}!"})

    DigestEmailDaemon.perform()
    ObanHelpers.perform_all()
    # Performing job(s) enqueued at previous step
    ObanHelpers.perform_all()

    assert_received {:email, email}
    assert email.to == [{user2.name, user2.email}]
    assert email.subject == "Your digest from #{Pleroma.Config.get(:instance)[:name]}"
  end
end
