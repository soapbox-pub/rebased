defmodule Pleroma.Repo.Migrations.CopyUsersInfoFieldsToUsers do
  use Ecto.Migration

  @jsonb_array_default "'[]'::jsonb"

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
    :invisible,
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
    :invisible,
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
    if direction() == :up do
      sets =
        for f <- @info_fields do
          set_field = "#{f} ="

          # Coercion of null::jsonb to NULL
          jsonb = "case when info->>'#{f}' IS NULL then null else info->'#{f}' end"

          cond do
            f in @jsonb_fields ->
              "#{set_field} #{jsonb}"

            f in @array_jsonb_fields ->
              "#{set_field} coalesce(#{jsonb}, #{@jsonb_array_default})"

            f in @int_fields ->
              "#{set_field} (info->>'#{f}')::int"

            f in @boolean_fields ->
              "#{set_field} coalesce((info->>'#{f}')::boolean, false)"

            f in @array_text_fields ->
              "#{set_field} ARRAY(SELECT jsonb_array_elements_text(#{jsonb}))"

            true ->
              "#{set_field} info->>'#{f}'"
          end
        end
        |> Enum.join(", ")

      execute("update users set " <> sets)

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
