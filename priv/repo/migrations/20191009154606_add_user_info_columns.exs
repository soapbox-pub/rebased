defmodule Pleroma.Repo.Migrations.AddUsersInfoColumns do
  use Ecto.Migration

  @jsonb_array_default "'[]'::jsonb"

  def change do
    alter table(:users) do
      add_if_not_exists(:banner, :map, default: %{})
      add_if_not_exists(:background, :map, default: %{})
      add_if_not_exists(:source_data, :map, default: %{})
      add_if_not_exists(:note_count, :integer, default: 0)
      add_if_not_exists(:follower_count, :integer, default: 0)
      add_if_not_exists(:following_count, :integer, default: nil)
      add_if_not_exists(:locked, :boolean, default: false, null: false)
      add_if_not_exists(:confirmation_pending, :boolean, default: false, null: false)
      add_if_not_exists(:password_reset_pending, :boolean, default: false, null: false)
      add_if_not_exists(:confirmation_token, :text, default: nil)
      add_if_not_exists(:default_scope, :string, default: "public")
      add_if_not_exists(:blocks, {:array, :text}, default: [])
      add_if_not_exists(:domain_blocks, {:array, :text}, default: [])
      add_if_not_exists(:mutes, {:array, :text}, default: [])
      add_if_not_exists(:muted_reblogs, {:array, :text}, default: [])
      add_if_not_exists(:muted_notifications, {:array, :text}, default: [])
      add_if_not_exists(:subscribers, {:array, :text}, default: [])
      add_if_not_exists(:deactivated, :boolean, default: false, null: false)
      add_if_not_exists(:no_rich_text, :boolean, default: false, null: false)
      add_if_not_exists(:ap_enabled, :boolean, default: false, null: false)
      add_if_not_exists(:is_moderator, :boolean, default: false, null: false)
      add_if_not_exists(:is_admin, :boolean, default: false, null: false)
      add_if_not_exists(:show_role, :boolean, default: true, null: false)
      add_if_not_exists(:settings, :map, default: nil)
      add_if_not_exists(:magic_key, :text, default: nil)
      add_if_not_exists(:uri, :text, default: nil)
      add_if_not_exists(:hide_followers_count, :boolean, default: false, null: false)
      add_if_not_exists(:hide_follows_count, :boolean, default: false, null: false)
      add_if_not_exists(:hide_followers, :boolean, default: false, null: false)
      add_if_not_exists(:hide_follows, :boolean, default: false, null: false)
      add_if_not_exists(:hide_favorites, :boolean, default: true, null: false)
      add_if_not_exists(:unread_conversation_count, :integer, default: 0)
      add_if_not_exists(:pinned_activities, {:array, :text}, default: [])
      add_if_not_exists(:email_notifications, :map, default: %{"digest" => false})
      add_if_not_exists(:mascot, :map, default: nil)
      add_if_not_exists(:emoji, :map, default: fragment(@jsonb_array_default))
      add_if_not_exists(:pleroma_settings_store, :map, default: %{})
      add_if_not_exists(:fields, :map, default: fragment(@jsonb_array_default))
      add_if_not_exists(:raw_fields, :map, default: fragment(@jsonb_array_default))
      add_if_not_exists(:discoverable, :boolean, default: false, null: false)
      add_if_not_exists(:invisible, :boolean, default: false, null: false)
      add_if_not_exists(:notification_settings, :map, default: %{})
      add_if_not_exists(:skip_thread_containment, :boolean, default: false, null: false)
    end
  end
end
