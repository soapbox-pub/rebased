defmodule Pleroma.Repo.Migrations.SetNotNullForOauthAuthorizations do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE oauth_authorizations
    ALTER COLUMN app_id SET NOT NULL,
    ALTER COLUMN token SET NOT NULL,
    ALTER COLUMN used SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE oauth_authorizations
    ALTER COLUMN app_id DROP NOT NULL,
    ALTER COLUMN token DROP NOT NULL,
    ALTER COLUMN used DROP NOT NULL")
  end
end
