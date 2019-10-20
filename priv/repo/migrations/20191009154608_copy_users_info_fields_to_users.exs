defmodule Pleroma.Repo.Migrations.CopyUsersInfoaddsToUsers do
  use Ecto.Migration

  @info_fields [
    :banner,
    :background,
    :source_data,
    :note_count,
    :follower_count,
    :following_count,
    :locked,
    :confirmation_pending,
    :password_reset_pending,
    :confirmation_token,
    :default_scope,
    :blocks,
    :domain_blocks,
    :mutes,
    :muted_reblogs,
    :muted_notifications,
    :subscribers,
    :deactivated,
    :no_rich_text,
    :ap_enabled,
    :is_moderator,
    :is_admin,
    :show_role,
    :settings,
    :magic_key,
    :uri,
    :hide_followers_count,
    :hide_follows_count,
    :hide_followers,
    :hide_follows,
    :hide_favorites,
    :unread_conversation_count,
    :pinned_activities,
    :email_notifications,
    :mascot,
    :emoji,
    :pleroma_settings_store,
    :fields,
    :raw_fields,
    :discoverable,
    :skip_thread_containment,
    :notification_settings
  ]

  @jsonb_fields [
    :banner,
    :background,
    :source_data,
    :settings,
    :email_notifications,
    :mascot,
    :pleroma_settings_store,
    :notification_settings
  ]

  @array_jsonb_fields [:emoji, :fields, :raw_fields]

  @int_fields [:note_count, :follower_count, :following_count, :unread_conversation_count]

  @boolean_fields [
    :locked,
    :confirmation_pending,
    :password_reset_pending,
    :deactivated,
    :no_rich_text,
    :ap_enabled,
    :is_moderator,
    :is_admin,
    :show_role,
    :hide_followers_count,
    :hide_follows_count,
    :hide_followers,
    :hide_follows,
    :hide_favorites,
    :discoverable,
    :skip_thread_containment
  ]

  @array_text_fields [
    :blocks,
    :domain_blocks,
    :mutes,
    :muted_reblogs,
    :muted_notifications,
    :subscribers,
    :pinned_activities
  ]

  def change do
    alter table(:users) do
      add(:banner, :map, default: %{})
      add(:background, :map, default: %{})
      add(:source_data, :map, default: %{})
      add(:note_count, :integer, default: 0)
      add(:follower_count, :integer, default: 0)
      add(:following_count, :integer, default: nil)
      add(:locked, :boolean, default: false, null: false)
      add(:confirmation_pending, :boolean, default: false, null: false)
      add(:password_reset_pending, :boolean, default: false, null: false)
      add(:confirmation_token, :text, default: nil)
      add(:default_scope, :string, default: "public")
      add(:blocks, {:array, :text}, default: [])
      add(:domain_blocks, {:array, :text}, default: [])
      add(:mutes, {:array, :text}, default: [])
      add(:muted_reblogs, {:array, :text}, default: [])
      add(:muted_notifications, {:array, :text}, default: [])
      add(:subscribers, {:array, :text}, default: [])
      add(:deactivated, :boolean, default: false, null: false)
      add(:no_rich_text, :boolean, default: false, null: false)
      add(:ap_enabled, :boolean, default: false, null: false)
      add(:is_moderator, :boolean, default: false, null: false)
      add(:is_admin, :boolean, default: false, null: false)
      add(:show_role, :boolean, default: true, null: false)
      add(:settings, :map, default: nil)
      add(:magic_key, :text, default: nil)
      add(:uri, :text, default: nil)
      add(:hide_followers_count, :boolean, default: false, null: false)
      add(:hide_follows_count, :boolean, default: false, null: false)
      add(:hide_followers, :boolean, default: false, null: false)
      add(:hide_follows, :boolean, default: false, null: false)
      add(:hide_favorites, :boolean, default: true, null: false)
      add(:unread_conversation_count, :integer, default: 0)
      add(:pinned_activities, {:array, :text}, default: [])
      add(:email_notifications, :map, default: %{"digest" => false})
      add(:mascot, :map, default: nil)
      add(:emoji, {:array, :map}, default: [])
      add(:pleroma_settings_store, :map, default: %{})
      add(:fields, {:array, :map}, default: nil)
      add(:raw_fields, {:array, :map}, default: [])
      add(:discoverable, :boolean, default: false, null: false)
      add(:notification_settings, :map, default: %{})
      add(:skip_thread_containment, :boolean, default: false, null: false)
    end

    if direction == :up do
      for f <- @info_fields do
        set_field = "update users set #{f} ="

        cond do
          f in @jsonb_fields ->
            execute("#{set_field} info->'#{f}'")

          f in @array_jsonb_fields ->
            execute("#{set_field} ARRAY(SELECT jsonb_array_elements(info->'#{f}'))")

          f in @int_fields ->
            execute("#{set_field} (info->>'#{f}')::int")

          f in @boolean_fields ->
            execute("#{set_field} coalesce((info->>'#{f}')::boolean, false)")

          f in @array_text_fields ->
            execute("#{set_field} ARRAY(SELECT jsonb_array_elements_text(info->'#{f}'))")

          true ->
            execute("#{set_field} info->>'#{f}'")
        end
      end

      for index_name <- [
            :users_deactivated_index,
            :users_is_moderator_index,
            :users_is_admin_index,
            :users_subscribers_index
          ] do
        drop_if_exists(index(:users, [], name: index_name))
      end
    end

    create_if_not_exists(index(:users, [:deactivated]))
    create_if_not_exists(index(:users, [:is_moderator]))
    create_if_not_exists(index(:users, [:is_admin]))
    create_if_not_exists(index(:users, [:subscribers]))
  end
end
