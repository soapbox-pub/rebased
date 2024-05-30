defmodule Pleroma.Repo.Migrations.AddMissingForeignKeys do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:announcement_read_relationships, :announcement_id))
    create_if_not_exists(index(:bookmarks, :activity_id))
    create_if_not_exists(index(:bookmarks, :folder_id))
    create_if_not_exists(index(:chats, :recipient))
    create_if_not_exists(index(:mfa_tokens, :authorization_id))
    create_if_not_exists(index(:mfa_tokens, :user_id))
    create_if_not_exists(index(:notifications, :activity_id))
    create_if_not_exists(index(:oauth_authorizations, :app_id))
    create_if_not_exists(index(:oauth_authorizations, :user_id))
    create_if_not_exists(index(:password_reset_tokens, :user_id))
    create_if_not_exists(index(:push_subscriptions, :token_id))
    create_if_not_exists(index(:report_notes, :activity_id))
    create_if_not_exists(index(:report_notes, :user_id))
    create_if_not_exists(index(:user_notes, :target_id))
  end
end
