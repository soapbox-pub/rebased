defmodule Pleroma.Repo.Migrations.SetNotNullForUserInviteTokens do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE user_invite_tokens
    ALTER COLUMN used SET NOT NULL,
    ALTER COLUMN uses SET NOT NULL,
    ALTER COLUMN invite_type SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE user_invite_tokens
    ALTER COLUMN used DROP NOT NULL,
    ALTER COLUMN uses DROP NOT NULL,
    ALTER COLUMN invite_type DROP NOT NULL")
  end
end
