# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DataMigrationProlongOAuthTokensValidUntil do
  use Ecto.Migration

  def up do
    expires_in = Pleroma.Config.get!([:oauth2, :token_expires_in])
    valid_until = NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in, :second)
    execute("update oauth_tokens set valid_until = '#{valid_until}'")
  end

  def down do
    :noop
  end
end
