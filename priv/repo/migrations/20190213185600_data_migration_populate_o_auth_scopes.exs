# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DataMigrationPopulateOAuthScopes do
  use Ecto.Migration

  def up do
    for t <- [:oauth_authorizations, :oauth_tokens] do
      execute("UPDATE #{t} SET scopes = apps.scopes FROM apps WHERE #{t}.app_id = apps.id;")
    end
  end

  def down, do: :noop
end
