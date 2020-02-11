# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.DigestEmailsWorkerTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  clear_config([:email_notifications, :digest])

  test "it sends digest emails" do
    Pleroma.Config.put([:email_notifications, :digest], %{
      active: true,
      inactivity_threshold: 7,
      interval: 7
    })

    user = insert(:user)

    date =
      Timex.now()
      |> Timex.shift(days: -10)
      |> Timex.to_naive_datetime()

    user2 = insert(:user, last_digest_emailed_at: date)
    {:ok, _} = User.switch_email_notifications(user2, "digest", true)
    CommonAPI.post(user, %{"status" => "hey @#{user2.nickname}!"})

    Pleroma.Workers.Cron.DigestEmailsWorker.perform(:opts, :pid)
    # Performing job(s) enqueued at previous step
    ObanHelpers.perform_all()

    assert_received {:email, email}
    assert email.to == [{user2.name, user2.email}]
    assert email.subject == "Your digest from #{Pleroma.Config.get(:instance)[:name]}"
  end
end
