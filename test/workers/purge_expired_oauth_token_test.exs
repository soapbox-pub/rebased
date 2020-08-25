# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredOAuthTokenTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  setup do: clear_config([:oauth2, :clean_expired_tokens], true)

  test "purges expired token" do
    user = insert(:user)
    app = insert(:oauth_app)

    {:ok, %{id: id}} = Pleroma.Web.OAuth.Token.create(app, user)

    assert_enqueued(
      worker: Pleroma.Workers.PurgeExpiredOAuthToken,
      args: %{token_id: id}
    )

    assert {:ok, %{id: ^id}} =
             perform_job(Pleroma.Workers.PurgeExpiredOAuthToken, %{token_id: id})
  end
end
