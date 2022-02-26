# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredTokenTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  setup do: clear_config([:oauth2, :clean_expired_tokens], true)

  test "purges expired oauth token" do
    user = insert(:user)
    app = insert(:oauth_app)

    {:ok, %{id: id}} = Pleroma.Web.OAuth.Token.create(app, user)

    assert_enqueued(
      worker: Pleroma.Workers.PurgeExpiredToken,
      args: %{token_id: id, mod: Pleroma.Web.OAuth.Token}
    )

    assert {:ok, %{id: ^id}} =
             perform_job(Pleroma.Workers.PurgeExpiredToken, %{
               token_id: id,
               mod: Pleroma.Web.OAuth.Token
             })

    assert Repo.aggregate(Pleroma.Web.OAuth.Token, :count, :id) == 0
  end

  test "purges expired mfa token" do
    authorization = insert(:oauth_authorization)

    {:ok, %{id: id}} = Pleroma.MFA.Token.create(authorization.user, authorization)

    assert_enqueued(
      worker: Pleroma.Workers.PurgeExpiredToken,
      args: %{token_id: id, mod: Pleroma.MFA.Token}
    )

    assert {:ok, %{id: ^id}} =
             perform_job(Pleroma.Workers.PurgeExpiredToken, %{
               token_id: id,
               mod: Pleroma.MFA.Token
             })

    assert Repo.aggregate(Pleroma.MFA.Token, :count, :id) == 0
  end
end
