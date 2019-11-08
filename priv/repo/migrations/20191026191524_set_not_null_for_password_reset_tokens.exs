defmodule Pleroma.Repo.Migrations.SetNotNullForPasswordResetTokens do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE password_reset_tokens
    ALTER COLUMN token SET NOT NULL,
    ALTER COLUMN user_id SET NOT NULL,
    ALTER COLUMN used SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE password_reset_tokens
    ALTER COLUMN token DROP NOT NULL,
    ALTER COLUMN user_id DROP NOT NULL,
    ALTER COLUMN used DROP NOT NULL")
  end
end
