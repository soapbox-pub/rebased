# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Info do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pleroma.User.Info

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:banner, :map, default: %{})
    field(:background, :map, default: %{})
    field(:source_data, :map, default: %{})
    field(:note_count, :integer, default: 0)
    field(:follower_count, :integer, default: 0)
    # Should be filled in only for remote users
    field(:following_count, :integer, default: nil)
    field(:locked, :boolean, default: false)
    field(:confirmation_pending, :boolean, default: false)
    field(:confirmation_token, :string, default: nil)
    field(:default_scope, :string, default: "public")
    field(:blocks, {:array, :string}, default: [])
    field(:domain_blocks, {:array, :string}, default: [])
    field(:mutes, {:array, :string}, default: [])
    field(:muted_reblogs, {:array, :string}, default: [])
    field(:subscribers, {:array, :string}, default: [])
    field(:deactivated, :boolean, default: false)
    field(:no_rich_text, :boolean, default: false)
    field(:ap_enabled, :boolean, default: false)
    field(:is_moderator, :boolean, default: false)
    field(:is_admin, :boolean, default: false)
    field(:show_role, :boolean, default: true)
    field(:keys, :string, default: nil)
    field(:settings, :map, default: nil)
    field(:magic_key, :string, default: nil)
    field(:uri, :string, default: nil)
    field(:topic, :string, default: nil)
    field(:hub, :string, default: nil)
    field(:salmon, :string, default: nil)
    field(:hide_followers, :boolean, default: false)
    field(:hide_follows, :boolean, default: false)
    field(:hide_favorites, :boolean, default: true)
    field(:pinned_activities, {:array, :string}, default: [])
    field(:mascot, :map, default: nil)
    field(:emoji, {:array, :map}, default: [])
    field(:pleroma_settings_store, :map, default: %{})

    field(:notification_settings, :map,
      default: %{
        "followers" => true,
        "follows" => true,
        "non_follows" => true,
        "non_followers" => true
      }
    )

    field(:skip_thread_containment, :boolean, default: false)

    # Found in the wild
    # ap_id -> Where is this used?
    # bio -> Where is this used?
    # avatar -> Where is this used?
    # fqn -> Where is this used?
    # host -> Where is this used?
    # subject _> Where is this used?
  end

  def set_activation_status(info, deactivated) do
    params = %{deactivated: deactivated}

    info
    |> cast(params, [:deactivated])
    |> validate_required([:deactivated])
  end

  def update_notification_settings(info, settings) do
    settings =
      settings
      |> Enum.map(fn {k, v} -> {k, v in [true, "true", "True", "1"]} end)
      |> Map.new()

    notification_settings =
      info.notification_settings
      |> Map.merge(settings)
      |> Map.take(["followers", "follows", "non_follows", "non_followers"])

    params = %{notification_settings: notification_settings}

    info
    |> cast(params, [:notification_settings])
    |> validate_required([:notification_settings])
  end

  def add_to_note_count(info, number) do
    set_note_count(info, info.note_count + number)
  end

  def set_note_count(info, number) do
    params = %{note_count: Enum.max([0, number])}

    info
    |> cast(params, [:note_count])
    |> validate_required([:note_count])
  end

  def set_follower_count(info, number) do
    params = %{follower_count: Enum.max([0, number])}

    info
    |> cast(params, [:follower_count])
    |> validate_required([:follower_count])
  end

  def set_mutes(info, mutes) do
    params = %{mutes: mutes}

    info
    |> cast(params, [:mutes])
    |> validate_required([:mutes])
  end

  def set_blocks(info, blocks) do
    params = %{blocks: blocks}

    info
    |> cast(params, [:blocks])
    |> validate_required([:blocks])
  end

  def set_subscribers(info, subscribers) do
    params = %{subscribers: subscribers}

    info
    |> cast(params, [:subscribers])
    |> validate_required([:subscribers])
  end

  def add_to_mutes(info, muted) do
    set_mutes(info, Enum.uniq([muted | info.mutes]))
  end

  def remove_from_mutes(info, muted) do
    set_mutes(info, List.delete(info.mutes, muted))
  end

  def add_to_block(info, blocked) do
    set_blocks(info, Enum.uniq([blocked | info.blocks]))
  end

  def remove_from_block(info, blocked) do
    set_blocks(info, List.delete(info.blocks, blocked))
  end

  def add_to_subscribers(info, subscribed) do
    set_subscribers(info, Enum.uniq([subscribed | info.subscribers]))
  end

  def remove_from_subscribers(info, subscribed) do
    set_subscribers(info, List.delete(info.subscribers, subscribed))
  end

  def set_domain_blocks(info, domain_blocks) do
    params = %{domain_blocks: domain_blocks}

    info
    |> cast(params, [:domain_blocks])
    |> validate_required([:domain_blocks])
  end

  def add_to_domain_block(info, domain_blocked) do
    set_domain_blocks(info, Enum.uniq([domain_blocked | info.domain_blocks]))
  end

  def remove_from_domain_block(info, domain_blocked) do
    set_domain_blocks(info, List.delete(info.domain_blocks, domain_blocked))
  end

  def set_keys(info, keys) do
    params = %{keys: keys}

    info
    |> cast(params, [:keys])
    |> validate_required([:keys])
  end

  def remote_user_creation(info, params) do
    info
    |> cast(params, [
      :ap_enabled,
      :source_data,
      :banner,
      :locked,
      :magic_key,
      :uri,
      :hub,
      :topic,
      :salmon,
      :hide_followers,
      :hide_follows,
      :follower_count,
      :following_count
    ])
  end

  def user_upgrade(info, params) do
    info
    |> cast(params, [
      :ap_enabled,
      :source_data,
      :banner,
      :locked,
      :magic_key,
      :follower_count,
      :following_count,
      :hide_follows,
      :hide_followers
    ])
  end

  def profile_update(info, params) do
    info
    |> cast(params, [
      :locked,
      :no_rich_text,
      :default_scope,
      :banner,
      :hide_follows,
      :hide_followers,
      :hide_favorites,
      :background,
      :show_role,
      :skip_thread_containment,
      :pleroma_settings_store
    ])
  end

  @spec confirmation_changeset(Info.t(), keyword()) :: Changeset.t()
  def confirmation_changeset(info, opts) do
    need_confirmation? = Keyword.get(opts, :need_confirmation)

    params =
      if need_confirmation? do
        %{
          confirmation_pending: true,
          confirmation_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
        }
      else
        %{
          confirmation_pending: false,
          confirmation_token: nil
        }
      end

    cast(info, params, [:confirmation_pending, :confirmation_token])
  end

  def mastodon_settings_update(info, settings) do
    params = %{settings: settings}

    info
    |> cast(params, [:settings])
    |> validate_required([:settings])
  end

  def mascot_update(info, url) do
    params = %{mascot: url}

    info
    |> cast(params, [:mascot])
    |> validate_required([:mascot])
  end

  def set_source_data(info, source_data) do
    params = %{source_data: source_data}

    info
    |> cast(params, [:source_data])
    |> validate_required([:source_data])
  end

  def admin_api_update(info, params) do
    info
    |> cast(params, [
      :is_moderator,
      :is_admin,
      :show_role
    ])
  end

  def add_pinnned_activity(info, %Pleroma.Activity{id: id}) do
    if id not in info.pinned_activities do
      max_pinned_statuses = Pleroma.Config.get([:instance, :max_pinned_statuses], 0)
      params = %{pinned_activities: info.pinned_activities ++ [id]}

      info
      |> cast(params, [:pinned_activities])
      |> validate_length(:pinned_activities,
        max: max_pinned_statuses,
        message: "You have already pinned the maximum number of statuses"
      )
    else
      change(info)
    end
  end

  def remove_pinnned_activity(info, %Pleroma.Activity{id: id}) do
    params = %{pinned_activities: List.delete(info.pinned_activities, id)}

    cast(info, params, [:pinned_activities])
  end

  def roles(%Info{is_moderator: is_moderator, is_admin: is_admin}) do
    %{
      admin: is_admin,
      moderator: is_moderator
    }
  end

  def add_reblog_mute(info, ap_id) do
    params = %{muted_reblogs: info.muted_reblogs ++ [ap_id]}

    cast(info, params, [:muted_reblogs])
  end

  def remove_reblog_mute(info, ap_id) do
    params = %{muted_reblogs: List.delete(info.muted_reblogs, ap_id)}

    cast(info, params, [:muted_reblogs])
  end
end
