# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.ClearOauthTokenWorkerTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  alias Pleroma.Workers.Cron.ClearOauthTokenWorker

  clear_config([:oauth2, :clean_expired_tokens])

  test "deletes expired tokens" do
    insert(:oauth_token,
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), -60 * 10)
    )

    Pleroma.Config.put([:oauth2, :clean_expired_tokens], true)
    ClearOauthTokenWorker.perform(:opts, :job)
    assert Pleroma.Repo.all(Pleroma.Web.OAuth.Token) == []
  end
end
