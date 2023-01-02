# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddScopesToPleromaFEOAuthRecords do
  use Ecto.Migration

  def up do
    update_scopes_clause = "SET scopes = '{read,write,follow,push,admin}'"
    apps_where = "WHERE apps.client_name like 'PleromaFE_%' or apps.client_name like 'AdminFE_%'"
    app_id_subquery_where = "WHERE app_id IN (SELECT apps.id FROM apps #{apps_where})"

    execute("UPDATE apps #{update_scopes_clause} #{apps_where}")

    for table <- ["oauth_authorizations", "oauth_tokens"] do
      execute("UPDATE #{table} #{update_scopes_clause} #{app_id_subquery_where}")
    end
  end

  def down, do: :noop
end
