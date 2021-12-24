# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.FollowingRelationship
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MediaProxy

  def render("index.json", %{users: users} = opts) do
    reading_user = opts[:for]

    relationships_opt =
      cond do
        Map.has_key?(opts, :relationships) ->
          opts[:relationships]

        is_nil(reading_user) || !opts[:embed_relationships] ->
          UserRelationship.view_relationships_option(nil, [])

        true ->
          UserRelationship.view_relationships_option(reading_user, users)
      end

    opts =
      opts
      |> Map.merge(%{relationships: relationships_opt, as: :user})
      |> Map.delete(:users)

    users
    |> render_many(AccountView, "show.json", opts)
    |> Enum.filter(&Enum.any?/1)
  end

  @doc """
  Renders specified user account.
    :skip_visibility_check option skips visibility check and renders any user (local or remote)
      regardless of [:pleroma, :restrict_unauthenticated] setting.
    :for option specifies the requester and can be a User record or nil.
      Only use `user: user, for: user` when `user` is the actual requester of own profile.
  """
  def render("show.json", %{user: _user, skip_visibility_check: true} = opts) do
    do_render("show.json", opts)
  end

  def render("show.json", %{user: user, for: for_user_or_nil} = opts) do
    if User.visible_for(user, for_user_or_nil) == :visible do
      do_render("show.json", opts)
    else
      %{}
    end
  end

  def render("show.json", _) do
    raise "In order to prevent account accessibility issues, " <>
            ":skip_visibility_check or :for option is required."
  end

  def render("mention.json", %{user: user}) do
    %{
      id: to_string(user.id),
      acct: user.nickname,
      username: username_from_nickname(user.nickname),
      url: user.uri || user.ap_id
    }
  end

  def render("relationship.json", %{user: nil, target: _target}) do
    %{}
  end

  def render(
        "relationship.json",
        %{user: %User{} = reading_user, target: %User{} = target} = opts
      ) do
    user_relationships = get_in(opts, [:relationships, :user_relationships])
    following_relationships = get_in(opts, [:relationships, :following_relationships])

    follow_state =
      if following_relationships do
        user_to_target_following_relation =
          FollowingRelationship.find(following_relationships, reading_user, target)

        User.get_follow_state(reading_user, target, user_to_target_following_relation)
      else
        User.get_follow_state(reading_user, target)
      end

    followed_by =
      if following_relationships do
        case FollowingRelationship.find(following_relationships, target, reading_user) do
          %{state: :follow_accept} -> true
          _ -> false
        end
      else
        User.following?(target, reading_user)
      end

    # NOTE: adjust UserRelationship.view_relationships_option/2 on new relation-related flags
    %{
      id: to_string(target.id),
      following: follow_state == :follow_accept,
      followed_by: followed_by,
      blocking:
        UserRelationship.exists?(
          user_relationships,
          :block,
          reading_user,
          target,
          &User.blocks_user?(&1, &2)
        ),
      blocked_by:
        UserRelationship.exists?(
          user_relationships,
          :block,
          target,
          reading_user,
          &User.blocks_user?(&1, &2)
        ),
      muting:
        UserRelationship.exists?(
          user_relationships,
          :mute,
          reading_user,
          target,
          &User.mutes?(&1, &2)
        ),
      muting_notifications:
        UserRelationship.exists?(
          user_relationships,
          :notification_mute,
          reading_user,
          target,
          &User.muted_notifications?(&1, &2)
        ),
      subscribing:
        UserRelationship.exists?(
          user_relationships,
          :inverse_subscription,
          target,
          reading_user,
          &User.subscribed_to?(&2, &1)
        ),
      requested: follow_state == :follow_pending,
      domain_blocking: User.blocks_domain?(reading_user, target),
      showing_reblogs:
        not UserRelationship.exists?(
          user_relationships,
          :reblog_mute,
          reading_user,
          target,
          &User.muting_reblogs?(&1, &2)
        ),
      endorsed: false
    }
  end

  def render("relationships.json", %{user: user, targets: targets} = opts) do
    relationships_opt =
      cond do
        Map.has_key?(opts, :relationships) ->
          opts[:relationships]

        is_nil(user) ->
          UserRelationship.view_relationships_option(nil, [])

        true ->
          UserRelationship.view_relationships_option(user, targets)
      end

    render_opts = %{as: :target, user: user, relationships: relationships_opt}
    render_many(targets, AccountView, "relationship.json", render_opts)
  end

  defp do_render("show.json", %{user: user} = opts) do
    user = User.sanitize_html(user, User.html_filter_policy(opts[:for]))
    display_name = user.name || user.nickname

    avatar = User.avatar_url(user) |> MediaProxy.url()
    avatar_static = User.avatar_url(user) |> MediaProxy.preview_url(static: true)
    header = User.banner_url(user) |> MediaProxy.url()
    header_static = User.banner_url(user) |> MediaProxy.preview_url(static: true)

    following_count =
      if !user.hide_follows_count or !user.hide_follows or opts[:for] == user,
        do: user.following_count,
        else: 0

    followers_count =
      if !user.hide_followers_count or !user.hide_followers or opts[:for] == user,
        do: user.follower_count,
        else: 0

    bot = user.actor_type == "Service"

    emojis =
      Enum.map(user.emoji, fn {shortcode, raw_url} ->
        url = MediaProxy.url(raw_url)

        %{
          shortcode: shortcode,
          url: url,
          static_url: url,
          visible_in_picker: false
        }
      end)

    relationship =
      if opts[:embed_relationships] do
        render("relationship.json", %{
          user: opts[:for],
          target: user,
          relationships: opts[:relationships]
        })
      else
        %{}
      end

    favicon =
      if Pleroma.Config.get([:instances_favicons, :enabled]) do
        user
        |> Map.get(:ap_id, "")
        |> URI.parse()
        |> URI.merge("/")
        |> Pleroma.Instances.Instance.get_or_update_favicon()
        |> MediaProxy.url()
      else
        nil
      end

    %{
      id: to_string(user.id),
      username: username_from_nickname(user.nickname),
      acct: user.nickname,
      display_name: display_name,
      locked: user.is_locked,
      created_at: Utils.to_masto_date(user.inserted_at),
      followers_count: followers_count,
      following_count: following_count,
      statuses_count: user.note_count,
      note: user.bio,
      url: user.uri || user.ap_id,
      avatar: avatar,
      avatar_static: avatar_static,
      header: header,
      header_static: header_static,
      emojis: emojis,
      fields: user.fields,
      bot: bot,
      source: %{
        note: user.raw_bio || "",
        sensitive: false,
        fields: user.raw_fields,
        pleroma: %{
          discoverable: user.is_discoverable,
          actor_type: user.actor_type
        }
      },

      # Pleroma extensions
      # Note: it's insecure to output :email but fully-qualified nickname may serve as safe stub
      fqn: User.full_nickname(user),
      pleroma: %{
        ap_id: user.ap_id,
        also_known_as: user.also_known_as,
        is_confirmed: user.is_confirmed,
        is_suggested: user.is_suggested,
        tags: user.tags,
        hide_followers_count: user.hide_followers_count,
        hide_follows_count: user.hide_follows_count,
        hide_followers: user.hide_followers,
        hide_follows: user.hide_follows,
        hide_favorites: user.hide_favorites,
        relationship: relationship,
        skip_thread_containment: user.skip_thread_containment,
        background_image: image_url(user.background) |> MediaProxy.url(),
        accepts_chat_messages: user.accepts_chat_messages,
        favicon: favicon
      }
    }
    |> maybe_put_role(user, opts[:for])
    |> maybe_put_settings(user, opts[:for], opts)
    |> maybe_put_notification_settings(user, opts[:for])
    |> maybe_put_settings_store(user, opts[:for], opts)
    |> maybe_put_chat_token(user, opts[:for], opts)
    |> maybe_put_activation_status(user, opts[:for])
    |> maybe_put_follow_requests_count(user, opts[:for])
    |> maybe_put_allow_following_move(user, opts[:for])
    |> maybe_put_unread_conversation_count(user, opts[:for])
    |> maybe_put_unread_notification_count(user, opts[:for])
    |> maybe_put_email_address(user, opts[:for])
  end

  defp username_from_nickname(string) when is_binary(string) do
    hd(String.split(string, "@"))
  end

  defp username_from_nickname(_), do: nil

  defp maybe_put_follow_requests_count(
         data,
         %User{id: user_id} = user,
         %User{id: user_id}
       ) do
    count =
      User.get_follow_requests(user)
      |> length()

    data
    |> Kernel.put_in([:follow_requests_count], count)
  end

  defp maybe_put_follow_requests_count(data, _, _), do: data

  defp maybe_put_settings(
         data,
         %User{id: user_id} = user,
         %User{id: user_id},
         _opts
       ) do
    data
    |> Kernel.put_in([:source, :privacy], user.default_scope)
    |> Kernel.put_in([:source, :pleroma, :show_role], user.show_role)
    |> Kernel.put_in([:source, :pleroma, :no_rich_text], user.no_rich_text)
  end

  defp maybe_put_settings(data, _, _, _), do: data

  defp maybe_put_settings_store(data, %User{} = user, %User{}, %{
         with_pleroma_settings: true
       }) do
    data
    |> Kernel.put_in([:pleroma, :settings_store], user.pleroma_settings_store)
  end

  defp maybe_put_settings_store(data, _, _, _), do: data

  defp maybe_put_chat_token(data, %User{id: id}, %User{id: id}, %{
         with_chat_token: token
       }) do
    data
    |> Kernel.put_in([:pleroma, :chat_token], token)
  end

  defp maybe_put_chat_token(data, _, _, _), do: data

  defp maybe_put_role(data, %User{show_role: true} = user, _) do
    data
    |> Kernel.put_in([:pleroma, :is_admin], user.is_admin)
    |> Kernel.put_in([:pleroma, :is_moderator], user.is_moderator)
  end

  defp maybe_put_role(data, %User{id: user_id} = user, %User{id: user_id}) do
    data
    |> Kernel.put_in([:pleroma, :is_admin], user.is_admin)
    |> Kernel.put_in([:pleroma, :is_moderator], user.is_moderator)
  end

  defp maybe_put_role(data, _, _), do: data

  defp maybe_put_notification_settings(data, %User{id: user_id} = user, %User{id: user_id}) do
    Kernel.put_in(
      data,
      [:pleroma, :notification_settings],
      Map.from_struct(user.notification_settings)
    )
  end

  defp maybe_put_notification_settings(data, _, _), do: data

  defp maybe_put_allow_following_move(data, %User{id: user_id} = user, %User{id: user_id}) do
    Kernel.put_in(data, [:pleroma, :allow_following_move], user.allow_following_move)
  end

  defp maybe_put_allow_following_move(data, _, _), do: data

  defp maybe_put_activation_status(data, user, %User{is_admin: true}) do
    Kernel.put_in(data, [:pleroma, :deactivated], !user.is_active)
  end

  defp maybe_put_activation_status(data, _, _), do: data

  defp maybe_put_unread_conversation_count(data, %User{id: user_id} = user, %User{id: user_id}) do
    data
    |> Kernel.put_in(
      [:pleroma, :unread_conversation_count],
      Pleroma.Conversation.Participation.unread_count(user)
    )
  end

  defp maybe_put_unread_conversation_count(data, _, _), do: data

  defp maybe_put_unread_notification_count(data, %User{id: user_id}, %User{id: user_id} = user) do
    Kernel.put_in(
      data,
      [:pleroma, :unread_notifications_count],
      Pleroma.Notification.unread_notifications_count(user)
    )
  end

  defp maybe_put_unread_notification_count(data, _, _), do: data

  defp maybe_put_email_address(data, %User{id: user_id}, %User{id: user_id} = user) do
    Kernel.put_in(
      data,
      [:pleroma, :email],
      user.email
    )
  end

  defp maybe_put_email_address(data, _, _), do: data

  defp image_url(%{"url" => [%{"href" => href} | _]}), do: href
  defp image_url(_), do: nil
end
