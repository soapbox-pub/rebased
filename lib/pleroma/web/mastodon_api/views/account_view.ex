# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.HTML
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MediaProxy

  def render("index.json", %{users: users} = opts) do
    users
    |> render_many(AccountView, "show.json", opts)
    |> Enum.filter(&Enum.any?/1)
  end

  def render("show.json", %{user: user} = opts) do
    if User.visible_for?(user, opts[:for]),
      do: do_render("show.json", opts),
      else: %{}
  end

  def render("mention.json", %{user: user}) do
    %{
      id: to_string(user.id),
      acct: user.nickname,
      username: username_from_nickname(user.nickname),
      url: User.profile_url(user)
    }
  end

  def render("relationship.json", %{user: nil, target: _target}) do
    %{}
  end

  def render("relationship.json", %{user: %User{} = user, target: %User{} = target}) do
    follow_state = User.get_cached_follow_state(user, target)

    requested =
      if follow_state && !User.following?(user, target) do
        follow_state == "pending"
      else
        false
      end

    %{
      id: to_string(target.id),
      following: User.following?(user, target),
      followed_by: User.following?(target, user),
      blocking: User.blocks_user?(user, target),
      blocked_by: User.blocks_user?(target, user),
      muting: User.mutes?(user, target),
      muting_notifications: User.muted_notifications?(user, target),
      subscribing: User.subscribed_to?(user, target),
      requested: requested,
      domain_blocking: User.blocks_domain?(user, target),
      showing_reblogs: User.showing_reblogs?(user, target),
      endorsed: false
    }
  end

  def render("relationships.json", %{user: user, targets: targets}) do
    render_many(targets, AccountView, "relationship.json", user: user, as: :target)
  end

  defp do_render("show.json", %{user: user} = opts) do
    display_name = user.name || user.nickname

    image = User.avatar_url(user) |> MediaProxy.url()
    header = User.banner_url(user) |> MediaProxy.url()

    following_count =
      if !user.hide_follows_count or !user.hide_follows or opts[:for] == user do
        user.following_count || 0
      else
        0
      end

    followers_count =
      if !user.hide_followers_count or !user.hide_followers or opts[:for] == user do
        user.follower_count || 0
      else
        0
      end

    bot = user.actor_type in ["Application", "Service"]

    emojis =
      (user.source_data["tag"] || [])
      |> Enum.filter(fn %{"type" => t} -> t == "Emoji" end)
      |> Enum.map(fn %{"icon" => %{"url" => url}, "name" => name} ->
        %{
          "shortcode" => String.trim(name, ":"),
          "url" => MediaProxy.url(url),
          "static_url" => MediaProxy.url(url),
          "visible_in_picker" => false
        }
      end)

    fields =
      user
      |> User.fields()
      |> Enum.map(fn %{"name" => name, "value" => value} ->
        %{
          "name" => name,
          "value" => Pleroma.HTML.filter_tags(value, Pleroma.HTML.Scrubber.LinksOnly)
        }
      end)

    bio = HTML.filter_tags(user.bio, User.html_filter_policy(opts[:for]))
    relationship = render("relationship.json", %{user: opts[:for], target: user})

    %{
      id: to_string(user.id),
      username: username_from_nickname(user.nickname),
      acct: user.nickname,
      display_name: display_name,
      locked: user.locked,
      created_at: Utils.to_masto_date(user.inserted_at),
      followers_count: followers_count,
      following_count: following_count,
      statuses_count: user.note_count,
      note: bio || "",
      url: User.profile_url(user),
      avatar: image,
      avatar_static: image,
      header: header,
      header_static: header,
      emojis: emojis,
      fields: fields,
      bot: bot,
      source: %{
        note: HTML.strip_tags((user.bio || "") |> String.replace("<br>", "\n")),
        sensitive: false,
        fields: user.raw_fields,
        pleroma: %{
          discoverable: user.discoverable,
          actor_type: user.actor_type
        }
      },

      # Pleroma extension
      pleroma: %{
        confirmation_pending: user.confirmation_pending,
        tags: user.tags,
        hide_followers_count: user.hide_followers_count,
        hide_follows_count: user.hide_follows_count,
        hide_followers: user.hide_followers,
        hide_follows: user.hide_follows,
        hide_favorites: user.hide_favorites,
        relationship: relationship,
        skip_thread_containment: user.skip_thread_containment,
        background_image: image_url(user.background) |> MediaProxy.url()
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
    Kernel.put_in(data, [:pleroma, :notification_settings], user.notification_settings)
  end

  defp maybe_put_notification_settings(data, _, _), do: data

  defp maybe_put_allow_following_move(data, %User{id: user_id} = user, %User{id: user_id}) do
    Kernel.put_in(data, [:pleroma, :allow_following_move], user.allow_following_move)
  end

  defp maybe_put_allow_following_move(data, _, _), do: data

  defp maybe_put_activation_status(data, user, %User{is_admin: true}) do
    Kernel.put_in(data, [:pleroma, :deactivated], user.deactivated)
  end

  defp maybe_put_activation_status(data, _, _), do: data

  defp maybe_put_unread_conversation_count(data, %User{id: user_id} = user, %User{id: user_id}) do
    data
    |> Kernel.put_in(
      [:pleroma, :unread_conversation_count],
      user.unread_conversation_count
    )
  end

  defp maybe_put_unread_conversation_count(data, _, _), do: data

  defp image_url(%{"url" => [%{"href" => href} | _]}), do: href
  defp image_url(_), do: nil
end
