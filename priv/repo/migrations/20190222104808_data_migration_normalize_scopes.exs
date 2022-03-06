# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DataMigrationNormalizeScopes do
  use Ecto.Migration

  def up do
    for t <- [:apps, :oauth_authorizations, :oauth_tokens] do
      execute("UPDATE #{t} SET scopes = string_to_array(array_to_string(scopes, ' '), ' ');")
    end
  end

  def down, do: :noop
end
